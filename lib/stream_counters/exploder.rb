# encoding: utf-8

module StreamCounters
  class Exploder
    def initialize(config, options={})
      @config = config
      @specials = options.fetch(:specials, [])
      @reducers = options.fetch(:reducers, {})
    end

    def explode(item)
      base_key_pairs = Hash[@config.base_keys.map { |k| [k, item[k]] }]
      return {} if check_nils(base_key_pairs, @config.base_keys)
      @config.dimensions.each_with_object({}) do |dimension, segments|
        segment = base_key_pairs.dup
        dimension.keys.each do |k|
          if box_segment = dimension.boxed_segments[k]
            segment[k] = box_segment.box(item[box_segment.metric])
          else
            segment[k] = item[k]
          end
        end
        discard_keys = dimension.discard_nil_segments.is_a?(Array) ? dimension.discard_nil_segments : dimension.keys
        next if dimension.discard_nil_segments && check_nils(segment, discard_keys)
        dimension.meta.each { |m| segment[m] = item[m] }
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
      value = item[metric.message]
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
            !item[metric.if_message]
          elsif metric.if_with_context
            permuted_segment_keys = segment.dup
            dimension.metrics.each { |m, _| permuted_segment_keys.delete(m) }
            !item.send(metric.if_with_context.to_sym, permuted_segment_keys)
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
end
