module L2meter
  class Configuration
    attr_writer :output
    attr_accessor :source, :prefix
    attr_reader :context, :key_formatter, :value_formatter, :output

    DEFAULT_KEY_FORMATTER = ->(key) do
      key.to_s.strip.downcase.gsub(/[^-a-z\d.#]+/, ?-)
    end

    DEFAULT_VALUE_FORMATTER = ->(value) do
      value = value.to_s
      value =~ /\s/ ? value.inspect : value
    end

    private_constant :DEFAULT_KEY_FORMATTER

    def initialize
      @sort = false
      @key_formatter = DEFAULT_KEY_FORMATTER
      @value_formatter = DEFAULT_VALUE_FORMATTER
      @output = $stdout
    end

    def format_keys(&block)
      @key_formatter = block
    end

    def format_values(&block)
      @value_formatter = block
    end

    def sort?
      @sort
    end

    def sort=(value)
      @sort = !!value
    end

    def context
      if block_given?
        @context = Proc.new
      else
        @context
      end
    end

    def context=(block_or_value)
      @context = block_or_value
    end
  end
end
