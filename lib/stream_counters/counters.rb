# encoding: utf-8

module StreamCounters
  class Counters
    def initialize(config, options={})
      @config = config
      @value_filters = options.fetch(:value_filters, {})
      @identity_filter = proc { |x| x }
      @metric_types = {}
      @specials = options.fetch(:specials, [])
      reset
    end
    
    def handle_item(item)
      keys = @config.main_keys.map { |k| item.send(k) }
      @config.dimensions.each do |dimension|
        segment_values = dimension.all_keys.map { |dim| item.send(dim) }
        counters_for_key = (@counters[keys] ||= {})
        counters_for_dim = (counters_for_key[dimension] ||= {})
        counters_for_seg = (counters_for_dim[segment_values] ||= default_counters(dimension))
        dimension.metrics.each do |metric, message|
          counters_for_seg[metric] += calculate_value(item, message)
        end
        @specials.each do |special|
          special.calculate(counters_for_seg, item)
        end
      end
    end
    
    def reset
      @counters = {}
      @metrics_counters = @config.dimensions.reduce({}) do |acc, dimension|
        acc[dimension] = Hash[dimension.metrics.map { |k, v| [k, 0] }].freeze
        acc
      end
    end
    
    def get(keys, dimension)
      @counters[keys][dimension]
    end
    
    def each(&block)
      @counters.keys.each do |keys|
        counters_for_keys = @counters[keys]
        counters_for_keys.keys.each do |dimension|
          counters_for_dims = counters_for_keys[dimension]
          counters_for_dims.keys.each do |segment|
            data = Hash[@config.main_keys.zip(keys) + dimension.all_keys.zip(segment)].merge!(counters_for_dims[segment])
            case block.arity
            when 1 then yield data
            else        yield data, dimension
            end
          end
        end
      end
    end
    
    def size
      @counters.size
    end
    
  protected
  
    def calculate_value(item, message)
      type = @metric_types[message]
      value = item.send(message)
      filter = @value_filters.fetch(type, @identity_filter)
      filter.call(value)
    end
    
  private
  
    def default_counters(dimension)
      @specials.reduce(@metrics_counters[dimension].dup) do |counters, special|
        counters.merge!(special.default)
      end
    end
  end
end
