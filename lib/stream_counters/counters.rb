# encoding: utf-8

module StreamCounters
  class Counters
    def initialize(config, options={})
      @config = config
      @specials = options.fetch(:specials, [])
      @reducers = options.fetch(:reducers, {})
      reset
    end
    
    def count(item)
      keys = @config.base_keys.map { |k| item.send(k) }
      @config.dimensions.each do |dimension|
        segment_values = dimension.all_keys.map { |dim| item.send(dim) }
        counters_for_key = (@counters[keys] ||= {})
        counters_for_dim = (counters_for_key[dimension] ||= {})
        counters_for_seg = (counters_for_dim[segment_values] ||= @metrics_counters[dimension].dup)
        dimension.metrics.each do |metric_name, metric|
          counters_for_seg[metric_name] = reduce(counters_for_seg[metric_name], item, metric)
        end
        
        if @specials.any?
          specials_for_key = (@special_counters[keys] ||= {})
          specials_for_dim = (specials_for_key[dimension] ||= {})
          specials_for_seg = (specials_for_dim[segment_values] ||= @specials.map { |special| special.new(keys, dimension) })

          specials_for_seg.each do |special|
            special.count(item)
          end
        end
      end
    end
    
    def reset
      @counters = {}
      @special_counters = {}
      @metrics_counters = @config.dimensions.reduce({}) do |acc, dimension|
        acc[dimension] = Hash[dimension.metrics.map { |name, metric| [name, metric.default] }].freeze
        acc
      end
      @special_counters.each { |special| special.reset }
    end
    
    def get(keys, dimension)
      merge_specials(@counters, keys, dimension)
    end
    
    def each(&block)
      @counters.keys.each do |keys|
        counters_for_keys = @counters[keys]
        counters_for_keys.keys.each do |dimension|
          counters_for_dim = merge_specials(@counters, keys, dimension)
          counters_for_dim.keys.each do |segment|
            data = Hash[@config.base_keys.zip(keys) + dimension.all_keys.zip(segment)].merge!(counters_for_dim[segment])
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
  
    def reduce(current_value, item, metric)
      value = item.send(metric.message)
      reducer = @reducers[metric.type]
      if reducer
      then reducer.call(current_value, value)
      else current_value + value
      end
    end
    
  private
  
    def merge_specials(counters, keys, dimension)
      counters_for_dim = counters[keys][dimension]
      if @specials.any?
        @special_counters[keys][dimension].reduce(counters_for_dim) do |counters, specials_for_dim|
          segment, specials_for_seg = specials_for_dim
          specials_for_seg.each do |special|
            counters[segment].merge!(special.value(segment))
          end
          counters
        end
      end
      counters_for_dim
    end
  end
end
