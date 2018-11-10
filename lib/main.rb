require 'parslet'

class JLisp < Parslet::Parser
  rule(:oparen) { str('(') >> space? }
  rule(:cparen) { str(')') >> space? }

  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }

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
    match('"')  >> space?
  }
  rule(:symbol) {
    match("'") >>
    match("[^'\s]").repeat(1).as(:symbol) >> space?
  }
  rule(:identifier) { match('[^\(\)\"\s]').repeat(1).as(:identifier) >> space? }

  rule(:atom) { number | boolean | string | symbol | identifier }

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

  rule(:invocation) {
    (
      oparen >>
      identifier.as(:func) >>
      expression.repeat.as(:args) >>
      cparen
    ).as(:invocation)
  }

  rule(:expression) {
    atom |
    define_expression |
    if_expression |
    invocation
  }

  rule(:sequence) { expression.repeat(1).as(:sequence) }

  rule(:program) { space? >> sequence }

  root(:program)
end

def parse(str)
  JLisp.new.parse(str)
rescue Parslet::ParseFailed => failure
  puts failure.parse_failure_cause.ascii_tree
end

def eval(ast, env)
  if ast.key? :identifier
    [env[ast[:identifier].to_s], env]
  elsif ast.key? :string
    [ast[:string], env]
  elsif ast.key? :number
    [ast[:number].to_f, env]
  elsif ast.key? :symbol
    [ast[:symbol].to_sym, env]
  elsif ast.key? :boolean
    [
      ast[:boolean].to_s[1] == 't' ? true : false,
      env
    ]
  elsif ast.key? :define_expression
    expr = ast[:define_expression]

    # Create a new function
    fn = ->(*args) do
      # Extend the env with the function itself, and a lookup
      # of each arg
      new_env = {}
      new_env[expr[:name][:identifier].to_s] = fn
      expr[:args].each_with_index do |arg, i|
        new_env[arg[:identifier].to_s] = args[i]
      end

      # Eval the body with the environment, and return just the result
      eval(expr[:body], env.merge(new_env)).first
    end

    new_env = {}
    # I guess we have to do this twice
    new_env[expr[:name][:identifier].to_s] = fn
    [:ok, env.merge(new_env)]
  elsif ast.key? :if_expression
    expr = ast[:if_expression]

    if eval(expr[:condition], env).first
      eval(expr[:consequent], env)
    else
      eval(expr[:alternate], env)
    end
  elsif ast.key? :invocation
    expr = ast[:invocation]
    fn = env[expr[:func][:identifier].to_s]

    # Eval each of the arguments
    args = expr[:args].map do |arg|
      eval(arg, env).first
    end

    [fn.(*args), env]
  elsif ast.key? :sequence
    # Reduce the expressions, extending the environment between each call
    init = [nil, env]
    result = ast[:sequence].reduce init do |memo, expr|
      eval(expr, memo[1])
    end

    [result.first, env]
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

src = <<-JLISP
  (define (plus a b)
    (+ a b))

  (list 10 (plus 5 6) 12)
JLISP

if __FILE__ == $0
  p eval_result(src)
end