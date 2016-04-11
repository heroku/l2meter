module L2meter
  class Emitter
    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
      @buffer = {}
      @autoflush = true
      @start_times = []
      @contexts = []
      @outputs = []
    end

    def log(*args)
      params = unwrap(*args)
      params = merge_contexts(params)

      if block_given?
        wrap params, &proc
      else
        write params
      end
    end

    def with_elapsed
      @start_times << Time.now
      yield
    ensure
      @start_times.pop
    end

    def silence
      silence!
      yield
    ensure
      unsilence!
    end

    def silence!
      @outputs.push NullObject.new
    end

    def unsilence!
      @outputs.pop
    end

    def measure(metric, value, unit: nil)
      log_with_prefix :measure, metric, value, unit: unit
    end

    def sample(metric, value, unit: nil)
      log_with_prefix :sample, metric, value, unit: unit
    end

    def count(metric, value = 1)
      log_with_prefix :count, metric, value
    end

    def unique(metric, value)
      log_with_prefix :unique, metric, value
    end

    def context(*context_data)
      return clone_with_context(context_data) unless block_given?
      push_context context_data
      yield
    ensure
      context_data.length.times { @contexts.pop }
    end

    def clone
      self.class.new(configuration: configuration)
    end

    def batch
      @autoflush = false
      yield
    ensure
      @autoflush = true
      flush_buffer
    end

    protected

    def push_context(context_data)
      @contexts.concat context_data.reverse
    end

    private

    def clone_with_context(context)
      clone.tap do |emitter|
        emitter.push_context context
      end
    end

    def unwrap(*args)
      params = Hash === args.last ? args.pop : {}
      args.compact.map { |key| [key, true] }.to_h.merge(params)
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), a| a[k.to_s] = v }
    end

    def merge_contexts(params)
      params = current_context.merge(params)
      source = configuration.source
      params = { source: source }.merge(params) if source

      if start_time = @start_times.last
        elapsed = Time.now - start_time
        params = merge_elapsed(elapsed, params)
      end

      params
    end

    def merge_elapsed(elapsed, params)
      params.merge(elapsed: "%.4fs" % elapsed)
    end

    def current_context
      contexts_queue.inject({}) do |result, context|
        context = context.call if context.respond_to?(:call)
        result.merge(unwrap(context))
      end.to_a.reverse.to_h
    end

    def format_value(value)
      configuration.value_formatter.call(value)
    end

    def format_key(key)
      configuration.key_formatter.call(key)
    end

    def write(params)
      @buffer.merge! stringify_keys(params)
      flush_buffer if @autoflush
    end

    def log_with_prefix(method, key, value, unit: nil)
      key = [configuration.prefix, key, unit].compact * ?.
      log Hash["#{method}##{key}", value]
    end

    def wrap(params)
      write params.merge(at: :start)

      result, error, elapsed = execute_with_elapsed(&proc)

      status = if error
        { at: :exception, exception: error.class, message: error.message.strip }
      else
        { at: :finish }
      end

      write params.merge(merge_elapsed(elapsed, status))

      raise error if error

      result
    end

    def execute_with_elapsed
      time_at_start = Time.now
      [yield, nil, Time.now - time_at_start]
    rescue Object => exception
      [nil, exception, Time.now - time_at_start]
    end

    def contexts_queue
      [configuration.context, *@contexts].compact
    end

    def output_queue
      [configuration.output, *@outputs].compact
    end

    def flush_buffer
      tokens = @buffer.map do |key, value|
        key = format_key(key)
        value == true ? key : "#{key}=#{format_value(value)}"
      end

      tokens.sort! if configuration.sort?

      output_queue.last.puts [*tokens].join(" ")
    ensure
      @buffer.clear
    end
  end
end
