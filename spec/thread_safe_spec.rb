require "spec_helper"

describe L2meter::ThreadSafe do
  def self.forwarded_methods
    emitter_methods = L2meter::Emitter.instance_methods
    object_methods = Object.instance_methods
    emitter_methods - object_methods
  end

  forwarded_methods.each do |forwarded_method|
    it "forwards ##{forwarded_method} to emitter" do
      emitter = double("L2meter::Emitter")
      allow(emitter).to receive(:clone).and_return(emitter)
      allow(emitter).to receive(:freeze).and_return(emitter)
      subject = described_class.new(emitter)
      expect(emitter).to receive(forwarded_method).with(:foo, :bar)
      subject.public_send forwarded_method, :foo, :bar
    end
  end
end
