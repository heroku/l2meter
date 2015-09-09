require "l2meter/version"

module L2meter
  extend self

  autoload :Configuration, "l2meter/configuration"
  autoload :Emitter,       "l2meter/emitter"

  def build
    Emitter.new.tap do |emitter|
      yield emitter.configuration if block_given?
    end
  end
end
