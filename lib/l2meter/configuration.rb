module L2meter
  class Configuration
    attr_writer :output

    def output
      @output ||= $stdout
    end

    def key_formatter
      @key_formatter ||= ->(key) do
        key.to_s.strip.downcase.gsub(/[^-a-z\d.]+/, ?-)
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
      @context_block = block
    end

    def context=(value)
      @static_context = value
    end

    def get_context
      return @static_context if @static_context
      @context_block ? @context_block.call.to_h : {}
    end
  end
end
