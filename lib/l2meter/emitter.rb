module L2meter
  class Emitter
    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
      @start_times = []
      @contexts = []
      @outputs = []
    end

    def log(*args)
      params = transform_log_args(*args)
      params = merge_contexts(params)

      if block_given?
        wrap params, &Proc.new
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

    def count(metric, value=1)
      log_with_prefix :count, metric, value
    end

    def unique(metric, value)
      log_with_prefix :unique, metric, value
    end

    def context(hash_or_proc)
      @contexts.push hash_or_proc
      yield
    ensure
      @contexts.pop
    end

    def clone
      self.class.new(configuration: configuration)
    end

    private

    def transform_log_args(*args)
      params = Hash === args.last ? args.pop : {}
      args = args.map { |key| [ key, true ] }.to_h
      args.merge(params)
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
      contexts_queue.inject({}) do |result, c|
        current = c.respond_to?(:call) ? c.call.to_h : c.clone
        result.merge(current)
      end.to_a.reverse.to_h
    end

    def format_value(value)
      configuration.value_formatter.call(value)
    end

    def format_key(key)
      configuration.key_formatter.call(key)
    end

    def format_keys(params)
      params.inject({}) do |normalized, (key, value)|
        normalized.tap { |n| n[format_key(key)] = value }
      end
    end

    def write(params)
      tokens = format_keys(params).map do |key, value|
        value == true ? key : [ key, format_value(value) ] * ?=
      end

      tokens.sort! if configuration.sort?

      output_queue.last.print tokens.join(" ") + "\n"
    end

    def log_with_prefix(method, key, value, unit: nil)
      key = [configuration.prefix, key, unit].compact * ?.
      log Hash["#{method}##{key}", value]
    end

    def wrap(params)
      write params.merge(at: :start)

      result, exception, elapsed = execute_with_elapsed(&Proc.new)

      if exception
        status = { at: :exception, exception: exception.class.name, message: exception.message.strip }
      else
        status = { at: :finish }
      end

      status = merge_elapsed(elapsed, status)

      write params.merge(status)

      raise exception if exception

      result
    end

    def execute_with_elapsed
      time_at_start = Time.now
      [ yield, nil, Time.now - time_at_start ]
    rescue Exception => exception
      [ nil, exception, Time.now - time_at_start ]
    end

    def contexts_queue
      [ configuration.context, *@contexts ].compact
    end

    def output_queue
      [ configuration.output, *@outputs ].compact
    end
  end
end
