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
      all_base_key_values = @config.base_keys.map { |k| item.send(k) }
      base_key_value_permuations = product_flatter(all_base_key_values)
      @config.dimensions.each do |dimension|
        dimension_segments = []
        dimension.keys.each do |dim|
          if dimension.boxed_segments[dim]
            box_segment = dimension.boxed_segments[dim]
            box_segment_value = box_segment.box(item.send(box_segment.metric))
            dimension_segments << box_segment_value if box_segment_value
          else
            dimension_segments << item.send(dim)
          end
        end
        segment_value_permutations = product_flatter(dimension_segments)
        meta_values = {}
        dimension.meta.each { |dim| meta_values[dim] = item.send(dim) }
        base_key_value_permuations.each do |base_key_values|
          segment_value_permutations.each do |segment_values|
            count_segment_values(segment_values, meta_values, dimension, base_key_values, item)
          end
        end
      end
      @items_counted += 1
    end
    
    def count_segment_values(segment_values, meta_values, dimension, base_key_values, item)
      actual_segment_values = segment_values.map { |seg_val| seg_val.is_a?(Hash) ? seg_val.each_key { |k| break k } : seg_val }
      return if dimension.discard_nil_segments && actual_segment_values.include?(nil) || actual_segment_values.empty?
      counters_for_seg = @counters[base_key_values][dimension][actual_segment_values]
      multiplier = 1
      segment_values.each do |seg_val|
        multiplier *= seg_val.each_value { |v| break v } if seg_val.is_a?(Hash)
      end
      counters_for_seg.merge!(dimension.metrics) do |metric_name, old_metric, metric|
        should_count = metric.if_message.nil? && metric.if_with_context.nil?
        should_count ||= metric.if_message && item.send(metric.if_message)
        should_count ||= metric.if_with_context && item.send(metric.if_with_context, Hash[dimension.keys.zip(segment_values)])

        should_count ? reduce(old_metric, item, metric, multiplier) : old_metric
      end
      counters_for_seg.merge!(meta_values) { |key, v1, v2| v1 || v2  }

      if @specials.any?
        @special_counters[base_key_values][dimension].each do |special|
          special.count(item)
        end
      end
    end

    def product_flatter(values)
      return [values] if values.none? { |e| e.is_a?(Enumerable) }

      mid = values.map do |val|
        case val
        when Hash
          val.map { |k,v| {k => v} }
        when Enumerable
          val.to_a
        else
          [val]
        end
      end
      mid.shift.product(*mid)
    end

    def metrics_counters_defaults(dimension)
      dimension_metrics = dimension.metrics
      dimension_metrics.merge(dimension_metrics) do |_, metric, _|
        default = metric.default
        if default.respond_to?(:call)
          default =
            case default.arity
            when 2 then default.call(metric, dimension)
            when 1 then default.call(metric)
            when 0 then default.call
            else raise(ArgumentError, "Wrong number of arguments in default value (#{default.arity})")
            end
        end
        default
      end
    end
    
    def reset
      @counters = Hash.new do |counters_for_key, base_keys|
        counters_for_key[base_keys] = Hash.new do |counters_for_dim, dimension|
          counters_for_dim[dimension] = Hash.new { |counters_for_seg, seg| counters_for_seg[seg] = metrics_counters_defaults(dimension) }
        end
      end
      @items_counted = 0
      @special_counters.each_value do |special|
        special.each_value do |dimension_counters|
          dimension_counters.each(&:reset)
        end
      end if !@special_counters.nil?
      @special_counters = Hash.new do |special_counters, base_keys|
        special_counters[base_keys] = Hash.new do |specials_for_key, dimension|
          specials_for_key[dimension] = @specials.map { |special| special.new(base_keys, dimension) }
        end
      end
    end
    
    def get(keys, dimension)
      merge_specials(@counters[keys][dimension], keys, dimension)
    end
    
    def each(&block)
      @counters.each do |keys, counters_for_keys|
        base_keys = Hash[@config.base_keys.zip(keys)]
        counters_for_keys.each do |dimension, counters_for_dim|
          merge_specials(counters_for_dim, keys, dimension).each do |segment, values|
            data = Hash[dimension.keys.zip(segment)].merge!(base_keys).merge!(values)
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

    def merge_specials(counters_for_dim, keys, dimension)
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
