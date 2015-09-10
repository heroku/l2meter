require "spec_helper"

describe L2meter::Emitter do
  let(:configuration) { L2meter::Configuration.new }
  subject { described_class.new(configuration: configuration) }
  let(:io) { StringIO.new }
  let(:output) { io.tap(&:rewind).read }

  before { configuration.output = io }

  describe "#log" do
    it "logs values" do
      subject.log :foo
      expect(output).to eq("foo\n")
    end

    it "logs key-value pairs" do
      subject.log foo: :bar
      expect(output).to eq("foo=bar\n")
    end

    it "logs arguments and key-value pairs" do
      subject.log :foo, :bar, fizz: :buzz
      expect(output).to eq("foo bar fizz=buzz\n")
    end

    it "formats keys" do
      subject.log :foo_bar, "Hello World", fizz_buzz: "fizz_buzz"
      expect(output).to eq("foo-bar hello-world fizz-buzz=fizz_buzz\n")
    end

    it "sorts tokens if specified by configuration" do
      configuration.sort = true
      subject.log :c, :b, :a, 123, foo: :bar
      expect(output).to eq("123 a b c foo=bar\n")
    end

    it "uses configuration to format keys" do
      configuration.format_keys &:upcase
      subject.log :foo
      expect(output).to eq("FOO\n")
    end

    it "formats values" do
      subject.log foo: "hello world"
      expect(output).to eq("foo=\"hello world\"\n")
    end

    it "uses formatter from configuration" do
      configuration.format_values &:upcase
      subject.log foo: "bar"
      expect(output).to eq("foo=BAR\n")
    end

    it "takes block" do
      Timecop.freeze do
        subject.log :foo do
          Timecop.freeze Time.now + 3
          subject.log :bar
        end
      end

      expect(output).to eq("foo at=start\nbar\nfoo at=finish elapsed=3.0000s\n")
    end

    it "logs exception inside the block" do
      action = -> do
        Timecop.freeze do
          subject.log :foo do
            subject.log :bar
            Timecop.freeze Time.now + 3
            raise "hello world"
          end
        end
      end

      expect(&action).to raise_error(RuntimeError, "hello world")
      expect(output).to eq("foo at=start\nbar\nfoo at=exception exception=RuntimeError message=\"hello world\" elapsed=3.0000s\n")
    end

    it "logs context" do
      configuration.context = { hello: "world" }
      subject.log :foo
      expect(output).to eq("hello=world foo\n")
    end
  end

  describe "#silence" do
    it "prevents from loggin to the output" do
      subject.silence do
        subject.log :foo
      end

      expect(output).to be_empty
    end
  end
end
