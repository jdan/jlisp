require_relative "../lib/main.rb"

describe "atoms" do
  it "should eval numbers" do
    expect(eval_result(' 5 ')).to eq 5
    expect(eval_result('123')).to eq 123
    expect(eval_result('1.05')).to eq 1.05
  end

  it "should eval strings" do
    expect(eval_result('"hello"')).to eq "hello"
  end

  it "should eval booleans" do
    expect(eval_result('#t')).to eq true
    expect(eval_result('#f')).to eq false
  end

  it "should eval symbols" do
    expect(eval_result(":hello")).to eq :hello
    expect(eval_result(":sym-*'")).to eq :"sym-*'"
  end
end

describe "sequences" do
  it "should return the last expression" do
    expect(eval_result('1 2 3')).to eq 3
  end
end

describe "invocation" do
  it "should be able to invoke functions" do
    # TODO: probably move stdlib elsewhere
    expect(eval_result('(+ 1 2)')).to eq 3
    expect(eval_result('(* (+ 1 3) 6)')).to eq 24
    expect(eval_result('(/ 1 2)')).to eq 0.5
    expect(eval_result('(= 1 2)')).to eq false

    expect(eval_result('(list 1 2 3)')).to eq [1, 2, 3]
    expect(eval_result("(car (list :1 2 3))")).to eq :"1"
    expect(eval_result('(cdr (list 1 2 3))')).to eq [2, 3]

    expect(eval_result('(and #t #t)')).to eq true
    expect(eval_result('(and #t #f)')).to eq false
    expect(eval_result('(or #t #t)')).to eq true
    expect(eval_result('(or #f #f)')).to eq false
  end
end

describe "define" do
  it "should be able to define functions" do
    expect(eval_result(
      '(define (plus1 x) (+ x 1)) (plus1 6)'
    )).to eq 7
  end
end

describe "if" do
  it "should eval if statements" do
    expect(eval_result(
      '(if 1 2 3)'
    )).to eq 2

    expect(eval_result(
      '(if (= (car (list 1 2 3))
              5)
           "ok"
           "no")'
    )).to eq "no"
    end
  end