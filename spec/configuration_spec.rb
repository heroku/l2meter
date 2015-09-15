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

  it "has a default source value" do
    expect(subject.source).to be_nil
  end

  it "allows setting source" do
    subject.source = "hello"
    expect(subject.source).to eq("hello")
  end

  it "has a default prefix value" do
    expect(subject.prefix).to be_nil
  end

  it "allows setting prefix" do
    subject.prefix = "hello"
    expect(subject.prefix).to eq("hello")
  end
end
