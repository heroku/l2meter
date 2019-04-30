require "spec_helper"

describe L2meter::ThreadSafe do
  def self.forwarded_clone_methods
    emitter_methods = L2meter::Emitter.instance_methods
    ts_overrides = L2meter::ThreadSafe.instance_methods
    object_methods = Object.instance_methods
    emitter_methods - ts_overrides - object_methods
  end

  let(:emitter) { L2meter::Emitter.new }
  before { allow(emitter).to receive(:freeze).and_return(emitter) }

  subject { described_class.new(emitter) }

  forwarded_clone_methods.each do |forwarded_method|
    it "forwards ##{forwarded_method} to emitter's clone" do
      emitter_clone = double("L2meter::Emitter")
      allow(emitter).to receive(:clone).and_return(emitter_clone)
      expect(emitter_clone).to receive(forwarded_method).with(:foo, :bar)
      subject.public_send forwarded_method, :foo, :bar
    end
  end

  describe "#disable!" do
    it "silences the object across all threads" do
      expect(emitter).to_not receive(:log)
      subject.disable!
      subject.log :foo
    end

    it "executes the blocks in disabled mode" do
      performed = false
      subject.disable!
      subject.log foo: :bar do
        performed = true
      end

      expect(performed).to eq(true)
    end
  end

  describe "#context" do
    it "wraps contexted emitter in thread-safe" do
      expect(subject.context(:foo)).to be_instance_of(described_class)
    end

    it "preserves disabled state" do
      expect_any_instance_of(L2meter::Emitter).to_not receive(:log)
      subject.disable!
      contexted = subject.context(:foo)
      contexted.log :bar
    end
  end

  it "is actually thread-safe" do
    output = StringIO.new
    subject.configuration.output = output

    thread_a = Thread.new do
      10_000.times do
        subject.context :bar do
          subject.log :hi
        end
      end
    end

    thread_b = Thread.new do
      10_000.times do
        subject.log :bye
      end
    end

    [thread_a, thread_b].each &:join

    lines = output.tap(&:rewind).read.lines.uniq
    expect(lines).to contain_exactly("bar hi\n", "bye\n")
  end
end
