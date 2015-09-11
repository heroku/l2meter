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
      params = context.merge(params)

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

    private

    def context
      configuration.get_context
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
