# encoding: utf-8


module StreamCounters
  class Configuration
    attr_reader :base_keys, :metrics, :dimensions
    
    def initialize(*args)
      if args.length == 1 && args.first.is_a?(Hash)
        deserialize(args.first)
      else
        base_keys, metrics, dimensions, dsl_context = args
        @base_keys = base_keys.map(&:to_s)
        @metrics = metrics
        @dimensions = dimensions
        @context = dsl_context
      end
    end
    
    def find_dimension(*keys)
      @dimensions.find { |d| d.keys == keys }
    end
    
    def create_counters(options={})
      Counters.new(self, options)
    end

    def create_exploder(options={})
      Exploder.new(self, options)
    end
    
    def validate_class(cls)
      (necessary_methods - cls.instance_methods.map(&:to_s)).sort
    end
    
    def validate_class!(cls)
      missing_methods = validate_class(cls)
      raise TypeError, "The class #{cls} is missing the methods #{missing_methods.join(', ')}", [] unless missing_methods.empty?
    end
    
    def to_h
      hash = {'base_keys' => @base_keys.to_a, 'metrics' => {}, 'dimensions' => {}}
      @metrics.each do |k, m|
        hash['metrics'][k] = m.to_h
      end
      @dimensions.each do |d|
        hash['dimensions'][d.keys.join(" ")] = d.to_h
      end
      hash.merge!(super) if defined?(super)
      hash
    end

  protected
  
    def necessary_methods
      m = []
      m.concat(base_keys.to_a)
      m.concat(metrics.values.map(&:message).flatten)
      m.concat(metrics.values.map(&:if_message).flatten.compact)
      m.concat(metrics.values.map(&:if_with_context).flatten.compact)
      m.concat(dimensions.map(&:keys).flatten)
      m.concat(dimensions.map(&:meta).flatten)
      m.uniq
    end
    
    def deserialize(hash)
      @base_keys = Keys.new(*hash['base_keys'])
      @metrics = {}
      @dimensions = []
      hash['metrics'].each do |key, metric|
        @metrics[key] = Metric.new(metric)
      end
      hash['dimensions'].each do |key, dimension|
        options = {'meta' => dimension['meta'], 'base_keys' => dimension['base_keys'], 'metrics' => {}, 'boxed_segments' => {}}
        dimension['metrics'].each do |mk, m|
          options['metrics'][mk] = Metric.new(m)
        end
        dimension['boxed_segments'].each do |bs|
          options['boxed_segments'][bs['name']] = BoxedSegment.new(bs)
        end if dimension['boxed_segments']
        @dimensions << Dimension.new(*dimension['keys'], options)
      end
      super(hash) if defined?(super)
    end
  end
end
