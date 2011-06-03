# encoding: utf-8


module StreamCounters
  class Configuration
    attr_reader :main_keys, :metrics, :dimensions
    
    def initialize(main_keys, metrics, dimensions)
      @main_keys = main_keys
      @metrics = metrics
      @dimensions = dimensions
    end
    
    def find_dimension(*keys)
      @dimensions.find { |d| d.keys == keys }
    end
  end
end