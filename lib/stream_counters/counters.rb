# encoding: utf-8

module StreamCounters
  class Exploder
    def initialize(config, options={})
      @config = config
      @specials = options.fetch(:specials, [])
      @reducers = options.fetch(:reducers, {})
    end

    def explode(item)
      base_key_pairs = Hash[@config.base_keys.map { |k| [k, item.send(k)] }]
      return {} if check_nils(base_key_pairs, @config.base_keys)
      @config.dimensions.each_with_object({}) do |dimension, segments|
        segment = base_key_pairs.dup
        dimension.keys.each { |k| segment[k] = item.send(k) }
        next if dimension.discard_nil_segments && check_nils(segment, dimension.keys)
        dimension.meta.each { |m| segment[m] = item.send(m) }
        dimension.metrics.each { |m, metric| segment[m] = calculate_metric(dimension, metric, item) || default_value(dimension, metric) }
        permuted_segments = permute_segment(dimension, segment)
        permuted_segments.each do |permuted_segment|
          apply_specials!(dimension, permuted_segment, item)
          apply_ifs!(dimension, permuted_segment, item)
        end
        segments[dimension] = permuted_segments
      end
    end

    private

    def calculate_metric(dimension, metric, item)
      value = item.send(metric.message)
      value = reduce_value(dimension, metric, value) if value
      value
    end

    def permute_segment(dimension, segment)
      multipliers = {}
      dimension.base_keys.each do |k|
        if segment[k].is_a?(Enumerable)
          multipliers[k] = segment[k].to_a
        end
      end
      dimension.keys.each do |k|
        if segment[k].is_a?(Enumerable)
          multipliers[k] = segment[k].to_a
        end
      end
      if multipliers.empty?
        [segment]
      else
        permutations = []
        ks = multipliers.keys
        vs = multipliers.values
        vs.shift.product(*vs).each do |perm|
          permuted_segment = segment.dup
          ks.each_with_index do |k, i|
            permuted_segment[k] = perm[i]
          end
          permutations << permuted_segment
        end
        permutations
      end
    end

    def check_nils(segment, keys)
      keys.any? { |k| segment[k].nil? || (segment[k].respond_to?(:empty?) && segment[k].empty?) }
    end

    def apply_specials!(dimension, segment, item)
      @specials.each do |special|
        s = special.new(@config.base_keys, dimension)
        s.count(item)
        v = s.value(segment.values_at(*dimension.keys))
        segment.merge!(v)
      end
    end

    def apply_ifs!(dimension, segment, item)
      dimension.metrics.each do |m, metric|
        reset_to_default = begin
          if metric.if_message
            !item.send(metric.if_message)
          elsif metric.if_with_context
            permuted_segment_keys = segment.dup
            dimension.metrics.each { |m, _| permuted_segment_keys.delete(m) }
            !item.send(metric.if_with_context, permuted_segment_keys)
          else
            false
          end
        end
        if reset_to_default
          segment[m] = default_value(dimension, metric)
        end
      end
    end

    def default_value(dimension, metric)
      default = metric.default
      if default.respond_to?(:call)
        if default.respond_to?(:arity)
          value = begin
            case default.arity
            when 2 then default.call(metric, dimension)
            when 1 then default.call(metric)
            else default.call
            end
          end
        else
          default.call(metric, dimension)
        end
      elsif default.is_a?(Numeric) || default.is_a?(TrueClass) || default.is_a?(FalseClass) || default.is_a?(NilClass) || !default.respond_to?(:dup)
        value = default
      else
        value = default.dup
      end
    end

    def reduce_value(dimension, metric, value)
      reducer = @reducers[metric.type]
      if reducer
        d = default_value(dimension, metric)
        if reducer.arity == 3
          reducer.call(d, value, 1)
        else
          reducer.call(d, value)
        end
      else
        value
      end
    end
  end

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
            dimension_segments << box_segment_value
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
      counters_for_seg = @counters[dimension][base_key_values][actual_segment_values]
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
        @special_counters[dimension][base_key_values].each do |special|
          special.count(item)
        end
      end
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
      @counters = Hash.new do |counters_for_dim, dimension|
        counters_for_dim[dimension] = Hash.new do |counters_for_keys, base_keys|
          counters_for_keys[base_keys] = Hash.new { |counters_for_seg, seg| counters_for_seg[seg] = metrics_counters_defaults(dimension) }
        end
      end
      @items_counted = 0
      @special_counters.each_value do |dimension_counters|
        dimension_counters.each_value do |base_keys_counters|
          base_keys_counters.each(&:reset)
        end
      end if !@special_counters.nil?
      @special_counters = Hash.new do |special_counters, dimension|
        special_counters[dimension] = Hash.new do |specials_for_dim, base_keys|
          specials_for_dim[base_keys] = @specials.map { |special| special.new(base_keys, dimension) }
        end
      end
    end
    
    def get(keys, dimension)
      merge_specials(@counters[dimension][keys], @special_counters[dimension][keys])
    end
    
    def each(&block)
      @counters.merge!(@special_counters) do |dimension, counters_for_dim, specials_for_dim|
        counters_for_dim.merge!(specials_for_dim) do |keys, counters_for_keys, specials_for_keys|
          merge_specials(counters_for_keys, specials_for_keys)
          counters_for_keys
        end
        counters_for_dim
      end

      @counters.each do |dimension, counters_for_dim|
        counters_for_dim.each do |keys, counters_for_keys|
          base_keys = Hash[@config.base_keys.zip(keys)]
          counters_for_keys.each do |segment, values|
            data = Hash[dimension.keys.zip(segment)].merge!(base_keys).merge!(values)
            case block.arity
            when 1 then yield data
            else        yield data, dimension
            end
          end
        end
      end
    end

    # Deprecated: doesn't actually tell you anthing, returns the number of dimensions
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

    def merge_specials(counters_for_keys, specials_for_keys)
      if @specials.any?
        counters_for_keys.each do |segment, counter|
          specials_for_keys.each do |special|
            counter.merge!(special.value(segment))
          end
        end
      end
      counters_for_keys
    end
  end
end
