module L2meter
  class Configuration
    attr_writer :output
    attr_accessor :source

    def output
      @output ||= $stdout
    end

    def key_formatter
      @key_formatter ||= ->(key) do
        key.to_s.strip.downcase.gsub(/[^-a-z\d.#]+/, ?-)
      end
    end

    def format_keys(&block)
      @key_formatter = block
    end

    def value_formatter
      @value_formatter ||= ->(value) do
        value = value.to_s
        value =~ /\s/ ? value.inspect : value
      end
    end

    def format_values(&block)
      @value_formatter = block
    end

    def sort?
      defined?(@apply_sort) ? @apply_sort : false
    end

    def sort=(value)
      @apply_sort = !!value
    end

    def context(&block)
      @context = block
    end

    def context=(block_or_value)
      @context = block_or_value
    end

    def get_context
      return {} unless defined?(@context)
      @context.respond_to?(:call) ? @context.call.to_h : @context.clone
    end
  end
end
