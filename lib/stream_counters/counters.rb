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
      base_key_values = @config.base_keys.map { |k| item.send(k) }
      @config.dimensions.each do |dimension|
        segment_values = dimension.all_keys.map { |dim| item.send(dim) }
        counters_for_key = (@counters[base_key_values] ||= {})
        counters_for_dim = (counters_for_key[dimension] ||= {})
        counters_for_seg = (counters_for_dim[segment_values] ||= metrics_counters_defaults(dimension))
        dimension.metrics.each do |metric_name, metric|
          counters_for_seg[metric_name] = reduce(counters_for_seg[metric_name], item, metric) if metric.if_message.nil? || !!item.send(metric.if_message)
        end
        
        if @specials.any?
          specials_for_key = (@special_counters[base_key_values] ||= {})
          specials_for_dim = (specials_for_key[dimension] ||= @specials.map { |special| special.new(base_key_values, dimension) })

          specials_for_dim.each do |special|
            special.count(item)
          end
        end
      end
    end

    def metrics_counters_defaults(dimension)
      metrics_defaults = {}
      dimension.metrics.each do |name, metric|
        default = if metric.default.respond_to?(:call)
                    case metric.default.arity
                    when 2 then metric.default.call(metric, dimension)
                    when 1 then metric.default.call(metric)
                    when 0 then metric.default.call
                    else raise(ArgumentError, "Wrong number of arguments in default value (#{metric.default.arity})")
                    end
                  else
                    metric.default
                  end
        metrics_defaults[name] = default
      end
      metrics_defaults
    end
    
    def reset
      @counters = {}
      @special_counters.each do |key, special| 
        special.each do | dimension, dimension_counters |
          dimension_counters.each { |dimension_counter| dimension_counter.reset }
        end
      end if !@special_counters.nil?
      @special_counters = {}
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
        specials_for_dim = @special_counters[keys][dimension]
        counters_for_dim.each do |segment, counter|
          specials_for_dim.each do |special|
            counter.merge!(special.value(segment))
          end
        end
      end
      counters_for_dim
    end
  end
end
