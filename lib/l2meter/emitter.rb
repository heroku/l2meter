module L2meter
  class Emitter
    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
    end

    def log(*args, **params)
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

    def write(params)
      tokens = params.map do |key, value|
        key = configuration.key_formatter.call(key)
        next key if value == true
        value = configuration.value_formatter.call(value)
        [ key, value ] * ?=
      end

      tokens.sort! if configuration.sort?

      configuration.output.puts tokens.join(" ")
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
