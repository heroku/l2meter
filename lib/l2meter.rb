require "l2meter/version"

module L2meter
  extend self

  autoload :Configuration, "l2meter/configuration"
  autoload :Emitter,       "l2meter/emitter"
  autoload :NullOutput,    "l2meter/null_output"

  def build(configuration: Configuration.new)
    yield configuration if block_given?
    Emitter.new(configuration: configuration.freeze)
  end
end
