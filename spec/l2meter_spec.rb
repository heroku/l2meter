require "spec_helper"

describe L2meter do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "allows building an emitter using build method" do
    config = nil

    emitter = described_class.build do |configuration|
      config = configuration
    end

    expect(emitter).to be_kind_of(described_class::Emitter)
    expect(config).to eq(emitter.configuration)
  end
end
