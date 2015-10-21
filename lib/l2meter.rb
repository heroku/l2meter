require "l2meter/version"

module L2meter
  extend self

  autoload :Configuration, "l2meter/configuration"
  autoload :Emitter,       "l2meter/emitter"
  autoload :NullObject,    "l2meter/null_object"
  autoload :ThreadSafe,    "l2meter/thread_safe"

  def build(configuration: Configuration.new)
    yield configuration if block_given?
    emitter = Emitter.new(configuration: configuration.freeze)
    ThreadSafe.new(emitter)
  end
end
