require "forwardable"

module L2meter
  # This class is a wrapper around Emitter that makes sure that we have a
  # completely separate clone of Emitter per thread running. It doesn't truly
  # make Emitter thread-safe, it makes sure that you don't access the same
  # instance of emitter from different threads.
  class ThreadSafe
    extend Forwardable

    EMITTER_METHODS = %i[
      batch
      configuration
      count
      log
      measure
      push_context
      sample
      silence
      silence!
      unique
      unsilence!
      with_elapsed
    ]

    private_constant :EMITTER_METHODS

    def initialize(emitter)
      @emitter = emitter.freeze
    end

    def_delegators :receiver, *EMITTER_METHODS

    def context(*args, &block)
      value = emitter.context(*args, &block)
      block_given?? value : clone_with_emitter(value)
    end

    def disable!
      @disabled = true
    end

    protected

    attr_writer :emitter

    private

    attr_reader :emitter

    def clone_with_emitter(emitter)
      clone.tap do |ts|
        ts.emitter = emitter
      end
    end

    def receiver
      @disabled ? null_emitter : current_emitter
    end

    def current_emitter
      Thread.current[thread_key] ||= emitter.clone
    end

    def null_emitter
      @null_emitter ||= NullObject.new
    end

    def thread_key
      @thread_key ||= "_l2meter_emitter_#{emitter.object_id}".freeze
    end
  end
end
