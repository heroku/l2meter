require "spec_helper"

describe L2meter::Configuration do
  it "has default output io stream" do
    expect(subject.output).to eq($stdout)
  end

  it "allows setting output stream" do
    output = StringIO.new
    subject.output = output
    expect(subject.output).to eq(output)
  end

  it "has default key formatter" do
    { :foo_bar => "foo-bar", "Hello World" => "hello-world", 123 => "123" }.each do |key, formatted|
      expect(subject.key_formatter.call(key)).to eq(formatted)
    end
  end

  it "allows to specify key formatter" do
    formatter = ->{}
    subject.format_keys &formatter
    expect(subject.key_formatter).to eq(formatter)
  end

  it "has default value formatter" do
    { :foo => "foo", "hello world" => "\"hello world\"", 123 => "123" }.each do |value, formatted|
      expect(subject.value_formatter.call(value)).to eq(formatted)
    end
  end

  it "allows to specify value formatter" do
    formatter = ->{}
    subject.format_values &formatter
    expect(subject.value_formatter).to eq(formatter)
  end

  it "doesn't sort by default" do
    expect(subject.sort?).to eq(false)
  end

  it "allows to override sort" do
    subject.sort = 123
    expect(subject.sort?).to eq(true)
  end

  it "supports context" do
    expect(subject.get_context).to eq({})
  end

  it "supports settings static context" do
    subject.context = { foo: "bar" }
    expect(subject.get_context).to eq(foo: "bar")
  end

  it "supports setting as lambda" do
    counter = double
    expect(counter).to receive(:call).and_return(1).ordered
    expect(counter).to receive(:call).and_return(2).ordered

    subject.context do
      { hello: counter.call }
    end

    expect(subject.get_context).to eq(hello: 1)
    expect(subject.get_context).to eq(hello: 2)
  end
end
