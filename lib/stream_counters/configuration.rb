# encoding: utf-8


module StreamCounters
  class Configuration
    attr_reader :base_keys, :metrics, :dimensions
    
    def initialize(base_keys, metrics, dimensions)
      @base_keys = base_keys
      @metrics = metrics
      @dimensions = dimensions
    end
    
    def find_dimension(*keys)
      @dimensions.find { |d| d.keys == keys }
    end
    
    def create_counters(options={})
      Counters.new(self, options)
    end
    
    def validate_class(cls)
      necessary_methods = []
      necessary_methods.concat(base_keys.to_a)
      necessary_methods.concat(metrics.values.map(&:message).flatten)
      necessary_methods.concat(dimensions.map(&:keys).flatten)
      (necessary_methods - cls.instance_methods).sort
    end
    
    def validate_class!(cls)
      missing_methods = validate_class(cls)
      raise TypeError, "The class #{cls} is missing the methods #{missing_methods.join(', ')}", [] unless missing_methods.empty?
    end
  end
end