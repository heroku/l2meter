module L2meter
  class NullObject
    def method_missing(*)
      yield if block_given?
    end
  end
end
