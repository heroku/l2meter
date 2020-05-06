RSpec.describe L2meter::Emitter do
  let(:configuration) { L2meter::Configuration.new }
  let(:emitter) { described_class.new(configuration: configuration) }
  let(:io) { StringIO.new }
  let(:output) { io.tap(&:rewind).read }

  subject { emitter }

  before { configuration.output = io }

  describe "#log" do
    it "logs values" do
      subject.log(:foo)
      expect(output).to eq("foo\n")
    end

    it "skips nil-values" do
      subject.log(nil, :foo)
      expect(output).to eq("foo\n")
    end

    it "logs key-value pairs" do
      subject.log(foo: :bar)
      expect(output).to eq("foo=bar\n")
    end

    it "skips key-value pairs where value is nil" do
      subject.log(foo: :bar, fizz: nil)
      expect(output).to eq("foo=bar\n")
    end

    it "logs key-value pairs with string as keys" do
      subject.log("foo" => "bar")
      expect(output).to eq("foo=bar\n")
    end

    it "allows periods in keys by default" do
      subject.log("foo.bar" => 1)
      expect(output).to eq("foo.bar=1\n")
    end

    it "logs key-value pairs with numbers as keys" do
      subject.log(123 => "bar", 123.45 => "foo")
      expect(output).to eq("123=bar 123.45=foo\n")
    end

    it "logs arguments and key-value pairs" do
      subject.log(:foo, :bar, fizz: :buzz)
      expect(output).to eq("foo bar fizz=buzz\n")
    end

    it "never outputs the same token twice" do
      subject.log(:foo => 1, "fOO " => 2, " Foo" => 3, "foo" => 4)
      expect(output).to eq("foo=4\n")
    end

    it "formats keys" do
      subject.log(:foo_bar, "Hello World", fizz_buzz: "fizz_buzz")
      expect(output).to eq("foo-bar hello-world fizz-buzz=fizz_buzz\n")
    end

    describe "value formatter" do
      it "formats plain strings" do
        subject.log(foo: "bar")
        expect(output).to eq("foo=bar\n")
      end

      it "formats strings with space characters" do
        subject.log(foo: "  foo  \t\n\n\n\t bar  ")
        expect(output).to eq("foo=\"foo bar\"\n")
      end

      it "formats strings with quotes" do
        subject.log(foo: "foo\"bar")
        expect(output).to eq("foo=\"foo\\\"bar\"\n")
      end

      it "formats symbols as strings" do
        subject.log(foo: :bar, fizz: :__buzz__?)
        expect(output).to eq("foo=bar fizz=\"__buzz__?\"\n")
      end

      it "formats integers" do
        subject.log(foo: 123)
        expect(output).to eq("foo=123\n")
      end

      it "formats floats" do
        subject.log(foo: 1.23456789)
        expect(output).to eq("foo=1.2346\n")
      end

      it "respects float precision" do
        configuration.float_precision = 5
        subject.log(foo: 1.23456789)
        expect(output).to eq("foo=1.23457\n")
      end

      it "formats dates" do
        subject.log(foo: Date.new(2017, 1, 1))
        expect(output).to eq("foo=2017-01-01\n")
      end

      it "formats utc time" do
        subject.log(foo: Time.utc(2017, 1, 1, 1, 1, 1))
        expect(output).to eq("foo=2017-01-01T01:01:01Z\n")
      end

      it "formats non-utc time" do
        subject.log(foo: Time.new(2017, 1, 1, 1, 1, 1, 8 * 3600))
        expect(output).to eq("foo=2017-01-01T01:01:01+08:00\n")
      end

      it "formats hashes" do
        subject.log(foo: {foo: :bar})
        expect(output).to eq("foo=\"{:foo=>:bar}\"\n")
      end

      it "formats lambdas" do
        value = -> { :hello }
        subject.log(foo: value)
        expect(output).to eq("foo=hello\n")
      end

      it "formats procs" do
        counter = 0
        value = -> { counter += 1 }
        subject.log(foo: value, bar: value)
        subject.log(foo: value, bar: value)
        expect(output).to eq("foo=1 bar=2\nfoo=3 bar=4\n")
      end

      it "formats modules/classes" do
        MyClass = Class.new
        MyModule = Module.new
        subject.log(class: MyClass, module: MyModule)
        expect(output).to eq("class=MyClass module=MyModule\n")
      end

      it "formats arrays" do
        array = [
          true,
          false,
          :foo,
          Time.utc(2017, 1, 1, 1, 1, 1),
          Date.new(2017, 1, 1)
        ]

        subject.log(foo: array)
        expect(output).to eq("foo=true,false,foo,2017-01-01T01:01:01Z,2017-01-01\n")
      end
    end

    it "sorts tokens if specified by configuration" do
      configuration.sort = true
      subject.log(:c, :b, :a, 123, foo: :bar)
      expect(output).to eq("123 a b c foo=bar\n")
    end

    it "uses configuration to format keys" do
      configuration.format_keys(&:upcase)
      subject.log(:foo)
      expect(output).to eq("FOO\n")
    end

    it "formats values" do
      subject.log(foo: "hello world")
      expect(output).to eq("foo=\"hello world\"\n")
    end

    it "does not log empty lines" do
      subject.log(nil, foo: nil)
      expect(output).to be_empty
    end

    it "takes block" do
      Timecop.freeze do
        subject.log(:foo) do
          Timecop.freeze(Time.now + 3)
          subject.log(:bar)
        end
      end

      expect(output).to eq("foo at=start\nbar\nfoo at=finish elapsed=3.0000\n")
    end

    it "does not interrupt throw/catch" do
      value = catch(:value) {
        subject.log(foo: "bar") do
          throw :value, 123
          "foobar"
        end
      }

      expect(value).to eq(123)
    end

    it "returns the block return value" do
      block = -> { "return value" }
      expect(subject.log(foo: :bar, &block)).to eq("return value")
    end

    it "logs exception inside the block" do
      action = -> do
        Timecop.freeze do
          subject.log(:foo) do
            subject.log(:bar)
            Timecop.freeze(Time.now + 3)

            # We deliberately emit then lowest level possible Exception class
            # to make sure l2meter won't blow up on it and report properly. We
            # also make sure the exception is re-raised after reporting is
            # done.
            raise Exception, "hello world"
          end
        end
      end

      expect(&action).to raise_error(Exception, "hello world")
      expect(output).to eq("foo at=start\nbar\nfoo at=exception exception=Exception message=\"hello world\" elapsed=3.0000\n")
    end

    it "logs context" do
      configuration.context = {hello: "world"}
      subject.log(:foo)
      subject.log(:bar)
      expect(output).to eq("hello=world foo\nhello=world bar\n")
    end

    it "logs dynamic context" do
      client = double
      expect(client).to receive(:get_id).and_return("abcd").twice
      configuration.context = -> { {foo: client.get_id} }
      subject.log(bar: :bar)
      subject.log(fizz: :buzz)
      expect(output).to eq("foo=abcd bar=bar\nfoo=abcd fizz=buzz\n")
    end

    it "allows overriding context with arguments" do
      configuration.context = {foo: "context"}
      subject.log(foo: "argument")
      expect(output).to eq("foo=argument\n")
    end

    it "appends source to every message if specified" do
      configuration.source = "us-west"
      subject.log("regular log")
      subject.log(key: "value")
      subject.context(with: :context) do
        subject.log("hello world")
      end

      expected = "".tap do |log|
        log << "source=us-west regular-log\n"
        log << "source=us-west key=value\n"
        log << "source=us-west with=context hello-world\n"
      end

      expect(output).to eq(expected)
    end
  end

  describe "#with_elapsed" do
    it "appends elapsed to every log emitter in the block" do
      Timecop.freeze do
        subject.with_elapsed do
          Timecop.freeze(Time.now + 3)
          subject.log(:foo)
          Timecop.freeze(Time.now + 3)
          subject.log(:bar)
        end

        subject.log(:baz)
      end

      expect(output).to eq("elapsed=3.0000 foo\nelapsed=6.0000 bar\nbaz\n")
    end
  end

  describe "#silence" do
    it "prevents from logging to the output" do
      subject.silence do
        subject.log(:foo)
        contexted = subject.context(:hello)
        contexted.log(:world)
      end

      expect(output).to be_empty
    end
  end

  describe "#silence!" do
    it "silences the emitter" do
      subject.log(:foo)
      subject.silence!
      subject.log(:bar)
      expect(output).to eq("foo\n")
    end
  end

  describe "#unsilence!" do
    it "disables previously set silence flag" do
      subject.log(:foo)
      subject.silence!
      subject.log(:bar)
      subject.unsilence!
      subject.log(:bazz)
      expect(output).to eq("foo\nbazz\n")
    end
  end

  describe "#context" do
    describe "with block" do
      it "supports setting context for a block as hash" do
        subject.context(foo: "foo") do
          subject.log(bar: :bar)
        end

        expect(output).to eq("foo=foo bar=bar\n")
      end

      it "supports rich context" do
        subject.context(:foo, :bar, hello: :world) do
          subject.log(fizz: :bazz)
        end
        expect(output).to eq("foo bar hello=world fizz=bazz\n")
      end

      it "supports dynamic context" do
        client = double
        expect(client).to receive(:get_id).and_return("abcd")
        subject.context(-> { {foo: client.get_id} }) do
          subject.log(bar: :bar)
        end

        expect(output).to eq("foo=abcd bar=bar\n")
      end

      it "supports nested context" do
        subject.context(foo: :foo) do
          subject.context(-> { {bar: :bar} }) do
            subject.log(hello: :world)
          end
        end

        expect(output).to eq("foo=foo bar=bar hello=world\n")
      end

      it "prefers internal context over the external one" do
        subject.context(foo: :foo) do
          subject.context(foo: :bar) do
            subject.log("hello world")
          end
        end

        expect(output).to eq("foo=bar hello-world\n")
      end

      it "prefers direct logging values over context" do
        subject.context(foo: :foo) do
          subject.log(foo: :bar)
        end

        expect(output).to eq("foo=bar\n")
      end
    end

    describe "without block" do
      it "returns a new instance of emitter with context" do
        contexted = subject.context(:foo, :bar, fizz: :buzz)
        contexted.log(hello: :world)
        expect(output).to eq("foo bar fizz=buzz hello=world\n")
      end

      it "does not affect original emitter" do
        _contexted = subject.context(:foo, :bar, fizz: :buzz)
        subject.log(hello: :world)
        expect(output).to eq("hello=world\n")
      end

      it "allows to use proc" do
        contexted = subject.context(-> { {foo: :bar} })
        contexted.log(hello: :world)
        expect(output).to eq("foo=bar hello=world\n")
      end
    end

    describe "mixed" do
      it "creating contexted emitter should not affect original emitter" do
        subject.context(foo: :bar) do
          subject.context(fizz: :buzz)
          subject.log(hello: :world)
        end

        expect(output).to eq("foo=bar hello=world\n")
      end

      it "contexted emitter should have original emitter's block-context" do
        contexted = nil
        subject.context(foo: :bar) do
          contexted = subject.context(fizz: :buzz)
          contexted.log(hello: :world)
        end

        expect(output).to eq("foo=bar fizz=buzz hello=world\n")
      end
    end
  end

  describe "#measure" do
    it "outputs a message with a measure prefix" do
      subject.measure(:thing, 10)
      expect(output).to eq("measure#thing=10\n")
    end

    it "supports unit argument" do
      subject.measure(:query, 200, unit: :ms)
      expect(output).to eq("measure#query.ms=200\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.measure(:query, 200, unit: :ms)
      expect(output).to eq("source=us-west measure#query.ms=200\n")
    end

    it "respects context" do
      subject.context(foo: :bar) do
        subject.measure(:baz, 10)
      end

      expect(output).to eq("foo=bar measure#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.measure(:query, 200, unit: :ms)
      expect(output).to eq("measure#my-app.query.ms=200\n")
    end
  end

  describe "#sample" do
    it "outputs a message with a sample prefix" do
      subject.sample(:thing, 10)
      expect(output).to eq("sample#thing=10\n")
    end

    it "supports unit argument" do
      subject.sample(:query, 200, unit: :ms)
      expect(output).to eq("sample#query.ms=200\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.sample(:query, 200, unit: :ms)
      expect(output).to eq("source=us-west sample#query.ms=200\n")
    end

    it "respects context" do
      subject.context(foo: :bar) do
        subject.sample("baz", 10)
      end

      expect(output).to eq("foo=bar sample#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.sample(:thing, 10)
      expect(output).to eq("sample#my-app.thing=10\n")
    end
  end

  describe "#count" do
    it "outputs a message with a count prefix" do
      subject.count(:thing, 123)
      expect(output).to eq("count#thing=123\n")
    end

    it "uses 1 as a default value" do
      subject.count(:thing)
      expect(output).to eq("count#thing=1\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.count(:thing)
      expect(output).to eq("source=us-west count#thing=1\n")
    end

    it "respects context" do
      subject.context(foo: :bar) do
        subject.count(:baz, 10)
      end

      expect(output).to eq("foo=bar count#baz=10\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.count(:thing)
      expect(output).to eq("count#my-app.thing=1\n")
    end
  end

  describe "#unique" do
    it "outputs a message with a unique prefix" do
      subject.unique(:registration, "user@example.com")
      expect(output).to eq("unique#registration=user@example.com\n")
    end

    it "includes source" do
      configuration.source = "us-west"
      subject.unique(:registration, "user@example.com")
      expect(output).to eq("source=us-west unique#registration=user@example.com\n")
    end

    it "respects context" do
      subject.context(foo: :bar) do
        subject.unique(:registration, "user@example.com")
      end

      expect(output).to eq("foo=bar unique#registration=user@example.com\n")
    end

    it "respects prefix" do
      configuration.prefix = "my-app"
      subject.unique(:registration, "bob@example.com")
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
        subject.log(foo: "a long value")
        subject.log(foo: "another long value")
        subject.unique(:registration, "user@example.com")
        subject.count(:thing, 10)
        subject.sample(:other_thing, 20)
      end

      expect(output).to eq("foo=\"another long value\" unique#registration=user@example.com count#thing=10 sample#other-thing=20\n")
    end

    it "includes the last value of the key if there are more than one" do
      subject.batch do
        subject.log(elapsed: 10)
        subject.log(elapsed: 20)
      end

      expect(output).to eq("elapsed=20\n")
    end

    it "allows nested batch calls" do
      subject.batch do
        subject.log(a: 1)

        subject.batch do
          subject.log(b: 2)
          subject.log(c: 3)
        end

        subject.log(d: 4)
      end

      expect(output).to eq("a=1 b=2 c=3 d=4\n")
    end
  end

  specify "#with_output" do
    other_output = StringIO.new
    subject.with_output(other_output) do
      subject.log(foo: :bar)
    end

    expect(output).to be_empty
    expect(other_output.tap(&:rewind).read).to eq("foo=bar\n")
  end

  describe "scrubbing" do
    it "scrubs based on key name" do
      configuration.scrubber = ->(key, value) do
        /password/.match?(key) ? "[scrubbed]" : value
      end

      subject.log(hello: :world, my_password: "this should be scrubbed")
      expect(output).to eq("hello=world my-password=[scrubbed]\n")
    end

    it "scrubs based on value" do
      configuration.scrubber = ->(key, value) do
        /secret/.match?(value) ? "[scrubbed]" : value
      end

      subject.log(
        hello: :world,
        my_password: "this secret schould be scrubbed",
        other_field: -> { "also secret, should be scrubbed" }
      )

      expect(output).to eq("hello=world my-password=[scrubbed] other-field=[scrubbed]\n")
    end

    it "allows to omit tokens when value is nil" do
      configuration.scrubber = ->(key, value) do
        /secret/.match?(value) ? nil : value
      end

      subject.log(
        hello: :world,
        my_password: "this secret schould be scrubbed",
        other_field: -> { "also secret, should be scrubbed" }
      )

      expect(output).to eq("hello=world\n")
    end
  end

  describe "thread-safety" do
    around { |example| Timecop.freeze(&example) }

    # this test is really crazy, but it works nice to prove that state
    # management is isolated per thread and logger is not stepping on its own
    # toes when called from multiple threads simulteneously
    it "is actually thread-safe" do
      thread_a = Thread.new {
        1_000.times do
          #=> thread=a line=1
          subject.context(thread: :a) do
            subject.log(line: 1)
          end
        end
      }

      thread_b = Thread.new {
        b_logger = subject.context(thread: :b)

        1_000.times do
          #=> thread=b line=2
          b_logger.log(line: 2)
        end
      }

      thread_c = Thread.new {
        1_000.times do
          #=> thread=c at=start
          #=> line=3
          #=> thread=c at=finish elapsed=0.0000
          subject.log(thread: :c) do
            subject.log(line: 3)
          end
        end
      }

      other_output = StringIO.new
      thread_d = Thread.new {
        1_000.times do
          subject.with_output(other_output) do
            #=> thread=d line=5
            subject.log(thread: :d, line: 5)
          end
        end
      }

      thread_e = Thread.new {
        1_000.times do
          subject.silence do
            subject.log(thread: :e, line: 6)
          end
        end
      }

      [
        thread_a,
        thread_b,
        thread_c,
        thread_d,
        thread_e
      ].each(&:join)

      lines = output.lines.uniq
      other_lines = other_output.tap(&:rewind).read.lines.uniq

      expect(lines).to contain_exactly(
        "thread=a line=1\n",
        "thread=b line=2\n",
        "thread=c at=start\n",
        "line=3\n",
        "thread=c at=finish elapsed=0.0000\n"
      )

      expect(other_lines).to contain_exactly("thread=d line=5\n")
    end
  end
end
