require "time"

module L2meter
  class Emitter
    attr_reader :configuration

    def initialize(configuration: Configuration.new)
      @configuration = configuration
      @buffer = {}
      @autoflush = true
      @contexts = []
      @outputs = []
    end

    def log(*args)
      merge! *current_contexts, *args

      if block_given?
        wrap &proc
      else
        write
      end
    end

    def with_elapsed(start_time = Time.now, &block)
      context(elapsed_context(start_time), &block)
    end

    def with_output(output)
      @outputs.push output
      yield
    ensure
      @outputs.pop
    end

    def silence
      with_output(NullObject.new, &proc)
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
      context_data.length.times { @contexts.pop } if block_given?
    end

    def clone
      cloned_contexts = @contexts.clone
      self.class.new(configuration: configuration).instance_eval do
        @contexts = cloned_contexts
        self
      end
    end

    def batch
      @autoflush = false
      yield
    ensure
      @autoflush = true
      fire!
    end

    def merge!(*args)
      @buffer.merge! format_keys(unwrap(args))
    end

    def scrub!
      configuration.scrubber.call(@buffer)
    end

    def fire!
      tokens = @buffer.map do |key, value|
        next if value.nil?
        key = format_key(key)
        value == true ? key : "#{key}=#{format_value(value)}"
      end.compact

      tokens.sort! if configuration.sort?

      output_queue.last.print tokens.join(SPACE) << NL if tokens.any?
    ensure
      @buffer.clear
    end

    protected

    def push_context(context_data)
      @contexts.concat context_data
    end

    private

    SPACE = " ".freeze
    NL    = "\n".freeze

    private_constant :SPACE, :NL

    def unwrap(args)
      args.each_with_object({}) do |context, result|
        next if context.nil?
        context = Hash[context, true] unless Hash === context
        result.merge! context
      end
    end

    def format_float(value, unit: nil)
      "%.#{configuration.float_precision}f#{unit}" % value
    end

    def clone_with_context(context)
      clone.tap do |emitter|
        emitter.push_context context
      end
    end

    def current_contexts
      contexts_queue.map do |context|
        context = context.call if context.respond_to?(:call)
        context
      end
    end

    def format_value(value)
      case value
      when /[^\w,.:@-]/
        value.strip.gsub(/\s+/, " ").inspect
      when String
        value.to_s
      when Float
        format_float(value)
      when Time
        value.iso8601
      when Proc
        format_value(value.call)
      when Hash
        format_value(value.inspect)
      when Array
        value.map(&method(:format_value)).join(?,)
      else
        format_value(value.to_s)
      end
    end

    def format_key(key)
      configuration.key_formatter.call(key)
    end

    def format_keys(hash)
      hash.each_with_object({}) { |(k, v), a| a[format_key(k)] = v }
    end

    def write(params = nil)
      merge! params
      scrub! if configuration.scrubber
      fire! if @autoflush
    end

    def log_with_prefix(method, key, value, unit: nil)
      key = [configuration.prefix, key, unit].compact * ?.
      log Hash["#{method}##{key}", value]
    end

    def wrap
      start_time = Time.now
      params = @buffer.clone
      write at: :start
      result = exception = nil

      begin
        result = yield
        merge! params, at: :finish
      rescue Object => exception
        merge! params, \
          at: :exception,
          exception: exception.class,
          message: exception.message
      end

      write elapsed_context(start_time)

      raise exception if exception

      result
    end

    def contexts_queue
      [configuration.context, source_context, *@contexts].compact
    end

    def output_queue
      [configuration.output, *@outputs].compact
    end

    def source_context
      { source: configuration.source }
    end

    def elapsed_context(since = Time.now)
      { elapsed: -> { elapsed_value(since) } }
    end

    def elapsed_value(since)
      format_float(Time.now - since, unit: ?s)
    end
  end
end
