module L2meter
  class NullObject
    Emitter.instance_methods(false).each do |method_name|
      define_method method_name do |*, &block|
        block && block.call
      end
    end

    def print(*); end
  end
end
