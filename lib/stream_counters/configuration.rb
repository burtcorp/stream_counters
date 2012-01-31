# encoding: utf-8


module StreamCounters
  class Configuration
    attr_reader :base_keys, :metrics, :dimensions
    
    def initialize(*args)
      if args.length == 1 && args[0].is_a?(Hash)
        deserialize(args[0])
      else
        base_keys, metrics, dimensions = args
        @base_keys = base_keys
        @metrics = metrics
        @dimensions = dimensions
      end
    end
    
    def find_dimension(*keys)
      @dimensions.find { |d| d.keys == keys }
    end
    
    def create_counters(options={})
      Counters.new(self, options)
    end
    
    def validate_class(cls)
      (necessary_methods - cls.instance_methods).sort
    end
    
    def validate_class!(cls)
      missing_methods = validate_class(cls)
      raise TypeError, "The class #{cls} is missing the methods #{missing_methods.join(', ')}", [] unless missing_methods.empty?
    end
    
    def to_h
      hash = {:base_keys => @base_keys.to_a, :metrics => {}, :dimensions => {}}
      @metrics.each do |k, m|
        hash[:metrics][k] = m.to_h
      end
      @dimensions.each do |d|
        hash[:dimensions][d.keys.join(" ")] = d.to_h
      end
      hash
    end

  protected
  
    def necessary_methods
      m = []
      m.concat(base_keys.to_a)
      m.concat(metrics.values.map(&:message).flatten)
      m.concat(metrics.values.map(&:if_message).flatten.compact)
      m.concat(dimensions.map(&:keys).flatten)
      m.concat(dimensions.map(&:meta).flatten)
      m.uniq
    end
    
    def deserialize(hash)
      @base_keys = Keys.new(*hash[:base_keys])
      @metrics = {}
      @dimensions = []
      hash[:metrics].each do |key, metric|
        @metrics[key] = Metric.new(metric)
      end
      hash[:dimensions].each do |key, dimension|
        options = {:meta => dimension[:meta], :base_keys => dimension[:base_keys], :metrics => {}}
        dimension[:metrics].each do |mk, m|
          options[:metrics][mk] = Metric.new(m)
        end
        @dimensions << Dimension.new(*dimension[:keys], options)
      end
    end
  end
end
