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
        segment_value_permutations = product_flatter(dimension.keys.map { |dim| item.send(dim) })
        meta_values = Hash[dimension.meta.zip(dimension.meta.map { |dim| item.send(dim) })]
        segment_value_permutations.each do |segment_values|
          count_segment_values(segment_values, meta_values, dimension, base_key_values, item)
        end
      end
      @items_counted += 1
    end
    
    def count_segment_values(segment_values, meta_values, dimension, base_key_values, item)
      actual_segment_values = segment_values.map { |seg_val| if seg_val.is_a?(Hash) then seg_val.keys.first else seg_val end }
      counters_for_key = (@counters[base_key_values] ||= {})
      counters_for_dim = (counters_for_key[dimension] ||= {})
      counters_for_seg = (counters_for_dim[actual_segment_values] ||= metrics_counters_defaults(dimension))
      dimension.metrics.each do |metric_name, metric|
        multiplier = segment_values.reduce(1) do |m, seg_val|
          m *= seg_val[seg_val.keys.first] if seg_val.is_a?(Hash)
          m
        end
        counters_for_seg[metric_name] = reduce(counters_for_seg[metric_name], item, metric, multiplier) if metric.if_message.nil? || item.send(metric.if_message)
      end
      counters_for_seg.merge!(meta_values) { |key, v1, v2| v1 || v2  }
      
      if @specials.any?
        specials_for_key = (@special_counters[base_key_values] ||= {})
        specials_for_dim = (specials_for_key[dimension] ||= @specials.map { |special| special.new(base_key_values, dimension) })

        specials_for_dim.each do |special|
          special.count(item)
        end
      end
    end

    def product_flatter(values)
      return [values] if values.none? { |e| e.is_a?(Enumerable) }
      
      case values.count
      when 1
        case values.first
        when Hash
          values.first.map { |k, v| [{k => v}] }
        else
          values.first.map { |o| [o] }
        end
      when 2
        wrapped_in_arrays = values.map do |val| 
          case val
          when Hash
            val.map { |k, v| {k => v} }
          when Enumerable
            val
          else
            [val]
          end
        end
        wrapped_in_arrays.first.product(wrapped_in_arrays.last)
      else
        raise(ArgumentError, "Not handling flattening of #{values.count} dimensions. Put up a task and we'll see what we can do =)")
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
      @items_counted = 0
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
            data = Hash[@config.base_keys.zip(keys) + dimension.keys.zip(segment)].merge!(counters_for_dim[segment])
            case block.arity
            when 1 then yield data
            else        yield data, dimension
            end
          end
        end
      end
    end

    # Deprecated: doesn't actually tell you anthing, returns the number of base keys,
    # which is an irrellevant number. Use #empty? to check if the counters are empty,
    # otherwise use #items_counted to see how many times #count has been called.
    def size
      @counters.size
    end

    def empty?
      @counters.empty?
    end

    def items_counted
      @items_counted
    end

  protected

    def reduce(current_value, item, metric, multiplier)
      value = item.send(metric.message)
      reducer = @reducers[metric.type]
      if reducer
        case reducer.arity
        when 3
          reducer.call(current_value, value, multiplier)
        else
          reducer.call(current_value, value)
        end
      else
        increment = value || 0
        increment *= multiplier if current_value.is_a?(Numeric)
        current_value + increment
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
