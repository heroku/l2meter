require "spec_helper"

describe L2meter::ThreadSafe do
  def self.forwarded_clone_methods
    emitter_methods = L2meter::Emitter.instance_methods
    object_methods = Object.instance_methods
    emitter_methods - object_methods
  end

  let :emitter do
    double("L2meter::Emitter").tap do |emitter|
      allow(emitter).to receive(:freeze).and_return(emitter)
    end
  end

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
  end
end
