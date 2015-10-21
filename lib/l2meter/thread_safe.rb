module L2meter
  # This class is a wrapper around Emitter that makes sure that we have a
  # completely separate clone of Emitter per thread running. It doesn't truly
  # make Emitter thread-safe, it makes sure that you don't access the same
  # instance of emitter from different threads.
  class ThreadSafe
    extend Forwardable

    EMITTER_METHODS = %i[
      configuration
      context
      count
      log
      measure
      sample
      silence
      unique
      with_elapsed
    ]

    private_constant :EMITTER_METHODS

    def initialize(emitter)
      @emitter = emitter.freeze
    end

    def_delegators :current_emitter, *EMITTER_METHODS

    private

    attr_reader :emitter

    def current_emitter
      Thread.current[thread_key] ||= emitter.clone
    end

    def thread_key
      @thread_key ||= "_l2meter_emitter_#{emitter.object_id}".freeze
    end
  end
end
