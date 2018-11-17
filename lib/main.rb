require 'parslet'

class JLisp < Parslet::Parser
  rule(:oparen) { str('(') >> space? }
  rule(:cparen) { str(')') >> space? }
  rule(:obrace) { str('[') >> space? }
  rule(:cbrace) { str(']') >> space? }
  rule(:ocurly) { str('{') >> space? }
  rule(:ccurly) { str('}') >> space? }

  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }

  rule(:nil_) {
    str('nil').as(:nil) >> space?
  }
  rule(:number) {
    (
      match('[0-9]').repeat(1) >>
      (str('.') >> match('[0-9]').repeat(1)).maybe
    ).as(:number) >> space?
  }
  rule(:boolean) {
    (
      str('#') >> (str('t') | str('f'))
    ).as(:boolean) >> space?
  }
  rule(:string) {
    match('"') >>
    match('[^"]').repeat.as(:string) >>
    match('"') >> space?
  }
  rule(:identifier) { match('[^\(\)\{\}\"\:\s]').repeat(1).as(:identifier) >> space? }
  rule(:symbol) {
    match(":") >> identifier.as(:symbol)
  }

  rule(:atom) { nil_ | number | boolean | string | symbol | identifier }

  rule(:define_expression) {
    (
      oparen >>
      str('define') >> space? >>
        oparen >>
          identifier.as(:name) >> identifier.repeat.as(:args) >>
        cparen >>
      sequence.as(:body) >>
      cparen
    ).as(:define_expression)
  }

  rule(:if_expression) {
    (
      oparen >>
      str('if') >> space? >>
        expression.as(:condition) >>
        expression.as(:consequent) >>
        expression.as(:alternate) >>
      cparen
    ).as(:if_expression)
  }

  rule(:lambda_expression) {
    (
      oparen >>
      str('fn') >> space? >>
        oparen >>
          identifier.repeat.as(:args) >>
        cparen >>
      expression.as(:body) >>
      cparen
    ).as(:lambda_expression)
  }

  rule(:let_expression) {
    (
      oparen >>
      str('let') >> space? >>
        obrace >>
          (
            oparen >>
              identifier >>
              expression.as(:value) >>
            cparen
          ).repeat.as(:bindings) >>
        cbrace >>
      expression.as(:body) >>
      cparen
    ).as(:let_expression)
  }

  rule(:do_expression) {
    oparen >>
      str('do') >> space? >>
      sequence >>
    cparen
  }

  rule(:map_expression) {
    (
      ocurly >>
      (
        symbol.as(:key) >> expression.as(:value)
      ).repeat.as(:pairs) >>
      ccurly
    ).as(:map_expression)
  }

  rule(:invocation) {
    (
      oparen >>
      expression.as(:func) >>
      expression.repeat.as(:args) >>
      cparen
    ).as(:invocation)
  }

  rule(:expression) {
    atom |
    define_expression |
    if_expression |
    lambda_expression |
    let_expression |
    do_expression |
    map_expression |
    invocation
  }

  rule(:sequence) { expression.repeat(1).as(:sequence) }

  rule(:program) { space? >> sequence }

  root(:program)
end

class ParseError < StandardError
end

def parse(str)
  JLisp.new.parse(str)
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
end

def eval(ast, env)
  if ast.key? :nil
    [nil, env]
  elsif ast.key? :identifier
    [env[ast[:identifier].to_s], env]
  elsif ast.key? :string
    [ast[:string], env]
  elsif ast.key? :number
    [ast[:number].to_f, env]
  elsif ast.key? :symbol
    [ast[:symbol][:identifier].to_sym, env]
  elsif ast.key? :boolean
    [
      ast[:boolean].to_s[1] == 't' ? true : false,
      env
    ]
  elsif ast.key? :define_expression
    expr = ast[:define_expression]

    # Create a new function
    fn = ->(*args) do
      ident = expr[:name][:identifier].to_s

      # Extend the env with the function itself, and a lookup
      # of each arg
      new_env = (
        expr[:args].map.with_index do |arg, i|
          [arg[:identifier].to_s, args[i]]
        end + [[ident, fn]]
      ).to_h

      # Eval the body with the environment, and return just the result
      eval(expr[:body], env.merge(new_env)).first
    end

    new_env = {}
    # I guess we have to do this twice
    new_env[expr[:name][:identifier].to_s] = fn
    [:ok, env.merge(new_env)]
  elsif ast.key? :lambda_expression
    expr = ast[:lambda_expression]
    fn = ->(*args) do
      new_env = expr[:args].map.with_index do |arg, i|
        [arg[:identifier].to_s, args[i]]
      end.to_h

      # Eval the body with the environment, and return just the result
      eval(expr[:body], env.merge(new_env)).first
    end

    [fn, env]
  elsif ast.key? :let_expression
    expr = ast[:let_expression]
    new_env = expr[:bindings].map do |binding|
      [
        binding[:identifier].to_s,
        eval(binding[:value], env).first
      ]
    end.to_h

    eval(expr[:body], env.merge(new_env))
  elsif ast.key? :if_expression
    expr = ast[:if_expression]

    if eval(expr[:condition], env).first
      eval(expr[:consequent], env)
    else
      eval(expr[:alternate], env)
    end
  elsif ast.key? :map_expression
    expr = ast[:map_expression]
    res = expr[:pairs].map do |pair|
      [
        eval(pair[:key], env).first,
        eval(pair[:value], env).first
      ]
    end.to_h

    [res, env]
  elsif ast.key? :invocation
    expr = ast[:invocation]
    fn = eval(expr[:func], env).first

    # Eval each of the arguments
    args = expr[:args].map do |arg|
      eval(arg, env).first
    end

    is_map_invocation =
      fn.is_a?(Hash) &&
      args.size == 1 &&
      args.first.is_a?(Symbol)

    if is_map_invocation
      [fn[args.first], env]
    else
      [fn.(*args), env]
    end
  elsif ast.key? :sequence
    # Reduce the expressions, extending the environment between each call
    init = [nil, env]
    result = ast[:sequence].reduce init do |memo, expr|
      eval(expr, memo[1])
    end

    [result.first, env]
  else
    raise ParseError.new("Unsure how to parse #{ast.keys.first}")
  end
end

def eval_result(src)
  fresh_env = {
    "+" => ->(a, b) { a + b },
    "-" => ->(a, b) { a - b },
    "*" => ->(a, b) { a * b },
    "/" => ->(a, b) { a / b },
    "=" => ->(a, b) { a == b },
    "and" => ->(a, b) { a && b },
    "or" => ->(a, b) { a || b },
    "list" => ->(*args) { args },
    "car" => ->(ls) { ls[0] },
    "cdr" => ->(ls) { ls.drop(1) },
  }
  eval(parse(src), fresh_env).first
end
