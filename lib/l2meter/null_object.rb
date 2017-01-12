module L2meter
  class NullObject
    # Silence forwardable stdlib warnings about forwarding private metods.
    def log(*)
      super
    end

    def method_missing(*)
      yield if block_given?
    end
  end
end
