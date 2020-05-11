require "time"

module L2meter
  class Emitter
    attr_reader :configuration

    BARE_VALUE_SENTINEL = Object.new.freeze

    def initialize(configuration: Configuration.new)
      @configuration = configuration
    end

    def log(*args, &block)
      merge!(current_context, *args)

      if block
        wrap(&block)
      else
        write
      end
    end

    def context(*context_data, &block)
      if block
        wrap_context(context_data, &block)
      else
        contexted(context_data)
      end
    end

    def with_elapsed
      context elapsed: elapse do
        yield
      end
    end

    def silence(&block)
      with_output(NullOutput.new, &block)
    end

    def silence!
      set_output(NullOutput.new)
    end

    def unsilence!
      set_output(nil)
    end

    def with_output(new_output)
      old_output = output
      set_output(new_output)
      yield
    ensure
      set_output(old_output)
    end

    def batch
      old_state = in_batch?
      in_batch!
      yield
    ensure
      reset_in_batch(old_state)
      write
    end

    def measure(metric, value, **args)
      log_with_prefix(:measure, metric, value, **args)
    end

    def sample(metric, value, **args)
      log_with_prefix(:sample, metric, value, **args)
    end

    def count(metric, value = 1)
      log_with_prefix(:count, metric, value)
    end

    def unique(metric, value)
      log_with_prefix(:unique, metric, value)
    end

    def clone
      original_contexts = dynamic_contexts
      original_output = output
      self.class.new(configuration: configuration).tap do |clone|
        clone.instance_eval do
          dynamic_contexts.concat(original_contexts)
          set_output original_output
        end
      end
    end

    private

    def log_with_prefix(method, key, value, unit: nil)
      key = [configuration.prefix, key, unit].compact.join(".")
      log(Hash["#{method}##{key}", value])
    end

    def elapse(since = Time.now)
      -> { Time.now - since }
    end

    def write(*args)
      merge!(*args)
      fire! unless in_batch?
    end

    def wrap(&block)
      elapsed = elapse
      cloned_buffer = buffer.clone
      write(at: :start)
      result, exception = capture(&block)
      merge!(cloned_buffer)
      if exception
        write(unwrap_exception(exception), elapsed: elapsed)
        raise(exception)
      else
        write(at: :finish, elapsed: elapsed)
        result
      end
    end

    def capture
      [yield, nil]
    rescue Object => exception
      [nil, exception]
    end

    def wrap_context(context_data)
      dynamic_contexts.concat(context_data)
      yield
    ensure
      context_data.each { dynamic_contexts.pop }
    end

    def contexted(context_data)
      clone.instance_eval do
        dynamic_contexts.concat(context_data)
        self
      end
    end

    def unwrap_exception(exception)
      {
        at: :exception,
        exception: exception.class,
        message: exception.message
      }
    end

    def current_context
      unwrap(resolved_contexts)
    end

    def current_contexts
      [
        source_context,
        configuration.context,
        *dynamic_contexts
      ].compact
    end

    def source_context
      configuration.source ? {source: configuration.source} : {}
    end

    def resolved_contexts
      current_contexts.map { |c| Proc === c ? c.call : c }
    end

    def fire!
      tokens = buffer.map { |k, v| build_token(k, v) }.compact
      tokens.sort! if configuration.sort?
      return if tokens.empty?
      output.print(tokens.join(SPACE) << NL)
    ensure
      buffer.clear
    end

    SPACE = " ".freeze
    NL = "\n".freeze

    private_constant :SPACE, :NL

    def scrub_value(key, value)
      scrubber = configuration.scrubber
      scrubber ? scrubber.call(key, value) : value
    end

    def build_token(key, value)
      case value
      when Proc
        build_token(key, value.call)
      else
        value = scrub_value(key, value)
        format_token(key, value)
      end
    end

    def format_token(key, value)
      case value
      when TrueClass
        key
      when FalseClass, NilClass
        nil
      when value == BARE_VALUE_SENTINEL
        key
      else
        value = format_value(value)
        "#{key}=#{value}"
      end
    end

    def format_value(value)
      case value
      when Float
        format_float_value(value)
      when String
        format_string_value(value)
      when Time
        format_time_value(value)
      when Array
        value.map(&method(:format_value)).join(",")
      else
        format_value(value.to_s)
      end
    end

    def format_time_value(value)
      value.iso8601
    end

    def format_float_value(value)
      format = "%.#{configuration.float_precision}f"
      sprintf(format, value)
    end

    def format_string_value(value)
      /[^\w,.:@\-\]\[]/.match?(value) ?
        value.strip.gsub(/\s+/, " ").inspect :
        value.to_s
    end

    def merge!(*args)
      unwrap(args.compact).each do |key, value|
        key = format_key(key)
        buffer[key] = value
      end
    end

    def format_key(key)
      configuration.key_formatter.call(key)
    end

    def unwrap(args)
      {}.tap do |result|
        args.each do |arg|
          next if arg.nil?
          arg = Hash[arg, BARE_VALUE_SENTINEL] unless Hash === arg
          arg.each do |key, value|
            result[key] = value
          end
        end
      end
    end

    def thread_state
      @mutex ||= Mutex.new
      @mutex.synchronize do
        @threads ||= {}

        # cleaning up state from dead threads
        @threads.delete_if { |t, _| !t.alive? }

        @threads[Thread.current] ||= {}
      end
    end

    def buffer
      thread_state[:buffer] ||= {}
    end

    def dynamic_contexts
      thread_state[:dynamic_contexts] ||= []
    end

    def output
      thread_state[:output] ||= configuration.output
    end

    def set_output(new_output)
      thread_state[:output] = new_output
    end

    def in_batch?
      !!thread_state[:in_batch]
    end

    def in_batch!
      reset_in_batch(true)
    end

    def reset_in_batch(new_value)
      thread_state[:in_batch] = new_value
    end
  end
end
