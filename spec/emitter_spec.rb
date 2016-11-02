require "spec_helper"

describe L2meter::Emitter do
  let(:configuration) { L2meter::Configuration.new }
  let(:emitter) { described_class.new(configuration: configuration) }
  let(:io) { StringIO.new }
  let(:output) { io.tap(&:rewind).read }

  subject { L2meter::ThreadSafe.new(emitter) }

  before { configuration.output = io }

  describe "#log" do
    it "logs values" do
      subject.log :foo
      expect(output).to eq("foo\n")
    end

    it "skips nil-values" do
      subject.log nil, :foo
      expect(output).to eq("foo\n")
    end

    it "logs key-value pairs" do
      subject.log foo: :bar
      expect(output).to eq("foo=bar\n")
    end

    it "skips key-value pairs where valus is nil" do
      subject.log foo: :bar, fizz: nil
      expect(output).to eq("foo=bar\n")
    end

    it "logs key-value pairs with string as keys" do
      subject.log "foo" => "bar"
      expect(output).to eq("foo=bar\n")
    end

    it "allows periods in keys by default" do
      subject.log "foo.bar" => 1
      expect(output).to eq("foo.bar=1\n")
    end

    it "logs key-value pairs with numbers as keys" do
      subject.log 123 => "bar", 123.45 => "foo"
      expect(output).to eq("123=bar 123.45=foo\n")
    end

    it "logs arguments and key-value pairs" do
      subject.log :foo, :bar, fizz: :buzz
      expect(output).to eq("foo bar fizz=buzz\n")
    end

    it "never outputs the same token twice" do
      subject.log foo: :bar, "foo" => "baz"
      expect(output).to eq("foo=baz\n")
    end

    it "formats keys" do
      subject.log :foo_bar, "Hello World", fizz_buzz: "fizz_buzz"
      expect(output).to eq("foo_bar hello_world fizz_buzz=fizz_buzz\n")
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

    it "does not log empty lines" do
      subject.log nil, foo: nil
      expect(output).to be_empty
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

    it "does not interrupt throw/catch" do
      value = catch(:value) do
        subject.log foo: "bar" do
          throw :value, 123
          "foobar"
        end
      end

      expect(value).to eq(123)
    end

    it "returns the block return value" do
      block = ->{ "return value" }
      expect(subject.log(foo: :bar, &block)).to eq("return value")
    end

    it "logs exception inside the block" do
      action = -> do
        Timecop.freeze do
          subject.log :foo do
            subject.log :bar
            Timecop.freeze Time.now + 3

            # We deliberately emit then lowest level possible Exception class
            # to make sure l2meter won't blow up on it and report properly. We
            # also make sure the exception is re-raised after reporting is
            # done.
            raise Exception, "hello world"
          end
        end
      end

      expect(&action).to raise_error(Exception, "hello world")
      expect(output).to eq("foo at=start\nbar\nfoo at=exception exception=Exception message=\"hello world\" elapsed=3.0000s\n")
    end

    it "logs context" do
      configuration.context = { hello: "world" }
      subject.log :foo
      subject.log :bar
      expect(output).to eq("hello=world foo\nhello=world bar\n")
    end

    it "logs dynamic context" do
      client = double
      expect(client).to receive(:get_id).and_return("abcd").twice
      configuration.context = ->{{ foo: client.get_id }}
      subject.log bar: :bar
      subject.log fizz: :buzz
      expect(output).to eq("foo=abcd bar=bar\nfoo=abcd fizz=buzz\n")
    end

    it "allows overriding context with arguments" do
      configuration.context = { foo: "context" }
      subject.log foo: "argument"
      expect(output).to eq("foo=argument\n")
    end

    it "appends source to every message if specified" do
      configuration.source = "us-west"
      subject.log "regular log"
      subject.log key: "value"
      subject.context with: :context do
        subject.log "hello world"
      end

      expected = String.new.tap do |log|
        log << "source=us-west regular_log\n"
        log << "source=us-west key=value\n"
        log << "source=us-west with=context hello_world\n"
      end

      expect(output).to eq(expected)
    end
  end

  describe "#with_elapsed" do
    it "appends elapsed to every log emitter in the block" do
      Timecop.freeze do
        subject.with_elapsed do
          Timecop.freeze Time.now + 3
          subject.log :foo
          Timecop.freeze Time.now + 3
          subject.log :bar
        end

        subject.log :baz
      end

      expect(output).to eq("foo elapsed=3.0000s\nbar elapsed=6.0000s\nbaz\n")
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

  describe "#silence!" do
    it "silences the emitter" do
      subject.log :foo
      subject.silence!
      subject.log :bar
      expect(output).to eq("foo\n")
    end
  end

  describe "#unsilence!" do
    it "disables previously set silence flag" do
      subject.log :foo
      subject.silence!
      subject.log :bar
      subject.unsilence!
      subject.log :bazz
      expect(output).to eq("foo\nbazz\n")
    end
  end

  describe "#context" do
    describe "with block" do
      it "supports setting context for a block as hash" do
        subject.context foo: "foo" do
          subject.log bar: :bar
        end

        expect(output).to eq("foo=foo bar=bar\n")
      end

      it "supports rich context" do
        subject.context :foo, :bar, hello: :world do
          subject.log fizz: :bazz
        end
        expect(output).to eq("foo bar hello=world fizz=bazz\n")
      end

      it "supports dynamic context" do
        client = double
        expect(client).to receive(:get_id).and_return("abcd")
        subject.context ->{{ foo: client.get_id }} do
          subject.log bar: :bar
        end

        expect(output).to eq("foo=abcd bar=bar\n")
      end

      it "supports nested context" do
        subject.context foo: :foo do
          subject.context ->{{ bar: :bar }} do
            subject.log hello: :world
          end
        end

        expect(output).to eq("bar=bar foo=foo hello=world\n")
      end

      it "prefers internal context over the external one" do
        subject.context foo: :foo do
          subject.context foo: :bar do
            subject.log "hello world"
          end
        end

        expect(output).to eq("foo=bar hello_world\n")
      end

      it "prefers direct logging values over context" do
        subject.context foo: :foo do
          subject.log foo: :bar
        end

        expect(output).to eq("foo=bar\n")
      end
    end

    describe "without block" do
      it "returns a new instance of emitter with context" do
        contexted = subject.context(:foo, :bar, fizz: :buzz)
        contexted.log hello: :world
        expect(output).to eq("foo bar fizz=buzz hello=world\n")
      end

      it "does not affect original emitter" do
        contexted = subject.context(:foo, :bar, fizz: :buzz)
        subject.log hello: :world
        expect(output).to eq("hello=world\n")
      end

      it "allows to use proc" do
        contexted = subject.context(->{{ foo: :bar }})
        contexted.log hello: :world
        expect(output).to eq("foo=bar hello=world\n")
      end
    end

    describe "mixed" do
      it "creating contexted emitter should not affect original emitter" do
        subject.context foo: :bar do
          subject.context(fizz: :buzz)
          subject.log hello: :world
        end

        expect(output).to eq("foo=bar hello=world\n")
      end

      it "contexted emitter should have original emitter's block-context" do
        contexted = nil
        subject.context foo: :bar do
          contexted = subject.context(fizz: :buzz)
          contexted.log hello: :world
        end

        expect(output).to eq("fizz=buzz foo=bar hello=world\n")
      end
    end
  end

  describe "#measure" do
    it "outputs a message with a measure prefix" do
      subject.measure :thing, 10
      expect(output).to eq("measure#thing=10\n")
    end

    it "supports unit argument" do
      subject.measure :query, 200, unit: :ms
      expect(output).to eq("measure#query.ms=200\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.measure :query, 200, unit: :ms
      expect(output).to eq("source=us-west measure#query.ms=200\n")
    end

    it "respects context" do
      subject.context foo: :bar do
        subject.measure :baz, 10
      end

      expect(output).to eq("foo=bar measure#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.measure :query, 200, unit: :ms
      expect(output).to eq("measure#my-app.query.ms=200\n")
    end
  end

  describe "#sample" do
    it "outputs a message with a sample prefix" do
      subject.sample :thing, 10
      expect(output).to eq("sample#thing=10\n")
    end

    it "supports unit argument" do
      subject.sample :query, 200, unit: :ms
      expect(output).to eq("sample#query.ms=200\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.sample :query, 200, unit: :ms
      expect(output).to eq("source=us-west sample#query.ms=200\n")
    end

    it "respects context" do
      subject.context foo: :bar do
        subject.sample "baz", 10
      end

      expect(output).to eq("foo=bar sample#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.sample :thing, 10
      expect(output).to eq("sample#my-app.thing=10\n")
    end
  end

  describe "#count" do
    it "outputs a message with a count prefix" do
      subject.count :thing, 123
      expect(output).to eq("count#thing=123\n")
    end

    it "uses 1 as a default value" do
      subject.count :thing
      expect(output).to eq("count#thing=1\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.count :thing
      expect(output).to eq("source=us-west count#thing=1\n")
    end

    it "respects context" do
      subject.context foo: :bar do
        subject.count :baz, 10
      end

      expect(output).to eq("foo=bar count#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.count :thing
      expect(output).to eq("count#my-app.thing=1\n")
    end
  end

  describe "#unique" do
    it "outputs a message with a unique prefix" do
      subject.unique :registration, "user@example.com"
      expect(output).to eq("unique#registration=user@example.com\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.unique :registration, "user@example.com"
      expect(output).to eq("source=us-west unique#registration=user@example.com\n")
    end

    it "respects context" do
      subject.context foo: :bar do
        subject.unique :registration, "user@example.com"
      end

      expect(output).to eq("foo=bar unique#registration=user@example.com\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.unique :registration, "bob@example.com"
      expect(output).to eq("unique#my-app.registration=bob@example.com\n")
    end
  end

  describe "#clone" do
    it "returns new emitter with same configuration" do
      clone = subject.clone
      expect(subject.configuration).to eq(clone.configuration)
    end
  end

  describe "#batch" do
    it "allows batching several log call into single line" do
      subject.batch do
        subject.log foo: "a long value"
        subject.log foo: "another long value"
        subject.unique :registration, "user@example.com"
        subject.count :thing, 10
        subject.sample :other_thing, 20
      end

      expect(output).to eq("foo=\"another long value\" unique#registration=user@example.com count#thing=10 sample#other_thing=20\n")
    end

    it "includes the last value of the key if there are more than one" do
      subject.batch do
        subject.log elapsed: 10
        subject.log elapsed: 20
      end

      expect(output).to eq("elapsed=20\n")
    end
  end

  specify "#with_output" do
    other_output = StringIO.new
    subject.with_output(other_output) do
      subject.log foo: :bar
    end

    expect(output).to be_empty
    expect(other_output.tap(&:rewind).read).to eq("foo=bar\n")
  end
end
