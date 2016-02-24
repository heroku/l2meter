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
      context
      count
      log
      measure
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

    def disable!
      @disabled = true
    end

    private

    attr_reader :emitter

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
