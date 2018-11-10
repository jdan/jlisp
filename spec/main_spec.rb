require_relative "../lib/main.rb"

describe "atoms" do
  it "should eval numbers" do
    expect(eval_result(' 5 ')).to eq 5
    expect(eval_result('123')).to eq 123
  end

  it "should eval strings" do
    expect(eval_result('"hello"')).to eq "hello"
  end
end

describe "sequences" do
  it "should return the last expression" do
    expect(eval_result('1 2 3')).to eq 3
  end
end

describe "invocation" do
  it "should be able to invoke functions" do
    expect(eval_result('(+ 1 2)')).to eq 3
    expect(eval_result('(* (+ 1 3) 6)')).to eq 24
  end
end

describe "define" do
  it "should be able to define functions" do
    expect(eval_result(
      '(define (plus1 x) (+ x 1)) (plus1 6)'
    )).to eq 7
  end
end