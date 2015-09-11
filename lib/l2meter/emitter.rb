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
      metric = ["measure", metric] * ?#
      metric = [metric, unit].compact * ?.
      write Hash[metric, value]
    end

    def context(hash_or_proc)
      old_context = @current_context
      @current_context = hash_or_proc
      yield
    ensure
      @current_context = old_context
    end

    private

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
