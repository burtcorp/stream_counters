# encoding: utf-8


module StreamCounters
  class Configuration
    attr_reader :main_keys, :sort_keys, :dimensions
    
    def initialize(main_keys, sort_keys, dimensions)
      @main_keys = main_keys
      @sort_keys = sort_keys
      @dimensions = dimensions
    end
    
    def find_dimension(*keys)
      @dimensions.find do |d|
        d.keys == keys
      end
    end
  end
end