module L2meter
  class Emitter
    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
    end

    def log(*args)
      params = Hash === args.last ? args.pop : {}
      args = args.map { |key| [ key, true ] }.to_h
      params = args.merge(params)
      params = configuration_context.merge(params)
      params = current_context.merge(params)
      params = merge_source(params)

      if block_given?
        wrap params, &Proc.new
      else
        write params
      end
    end

    def silence
      output = configuration.output
      configuration.output = NullObject.new
      yield
    ensure
      configuration.output = output
    end

    def measure(metric, value, unit: nil)
      metric = [metric, unit].compact * ?.
      log_with_prefix :measure, metric, value
    end

    def sample(metric, value, unit: nil)
      metric = [metric, unit].compact * ?.
      log_with_prefix :sample, metric, value
    end

    def count(metric, value=1)
      log_with_prefix :count, metric, value
    end

    def unique(metric, value)
      log_with_prefix :unique, metric, value
    end

    def context(hash_or_proc)
      old_context = @current_context
      @current_context = hash_or_proc
      yield
    ensure
      @current_context = old_context
    end

    private

    def merge_source(params)
      source = configuration.source
      source ? { source: source }.merge(params) : params
    end

    def configuration_context
      configuration.get_context
    end

    def current_context
      return {} unless defined?(@current_context)
      if @current_context.respond_to?(:call)
        @current_context.call.to_h
      else
        @current_context.to_h
      end
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

      configuration.output.print tokens.join(" ") + "\n"
    end

    def log_with_prefix(prefix, key, value)
      log Hash["#{prefix}##{key}", value]
    end

    def wrap(params)
      time_at_start = Time.now
      write params.merge(at: :start)
      yield
    rescue => error
      status = { at: :exception, exception: error.class.to_s, message: error.message.strip }
      raise
    else
      status = { at: :finish }
    ensure
      elapsed = Time.now - time_at_start
      status.merge! elapsed: "%.4fs" % elapsed
      write params.merge(status)
    end
  end
end
