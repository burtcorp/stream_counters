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
  end
end