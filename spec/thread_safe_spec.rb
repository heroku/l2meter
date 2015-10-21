require "spec_helper"

describe L2meter::ThreadSafe do
  class << self
    def forwarded_clone_methods
      emitter_methods = L2meter::Emitter.instance_methods
      object_methods = Object.instance_methods
      emitter_methods - object_methods - forwarded_direct_methods
    end

    def forwarded_direct_methods
      %i[silence! unsilence!]
    end
  end

  let :emitter do
    double("L2meter::Emitter").tap do |emitter|
      allow(emitter).to receive(:freeze).and_return(emitter)
    end
  end

  forwarded_clone_methods.each do |forwarded_method|
    it "forwards ##{forwarded_method} to emitter's clone" do
      emitter_clone = double("L2meter::Emitter")
      allow(emitter).to receive(:clone).and_return(emitter_clone)
      subject = described_class.new(emitter)
      expect(emitter_clone).to receive(forwarded_method).with(:foo, :bar)
      subject.public_send forwarded_method, :foo, :bar
    end
  end

  forwarded_direct_methods.each do |forwarded_method|
    it "forwards ##{forwarded_method} to emitter directly" do
      subject = described_class.new(emitter)
      expect(emitter).to receive(forwarded_method).with(:foo, :bar)
      subject.public_send forwarded_method, :foo, :bar
    end
  end
end
