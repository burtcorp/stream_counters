# encoding: utf-8

module StreamCounters
  class Counters
    def initialize(config, options={})
      @config = config
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
          value = case metric_type(message)
                  when :predicate then item.send(message) ? 1 : 0
                  when :numeric   then item.send(message)
                  end
          counters_for_seg[metric] += value unless value < 0
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
    
    def each
      @counters.keys.each do |keys|
        counters_for_keys = @counters[keys]
        counters_for_keys.keys.each do |dimension|
          counters_for_dims = counters_for_keys[dimension]
          counters_for_dims.keys.each do |segment|
            yield(
              :keys => Hash[@config.main_keys.zip(keys)], 
              :dimension => dimension, 
              :segments => Hash[dimension.all_keys.zip(segment)],
              :metrics => counters_for_dims[segment]
            )
          end
        end
      end
    end
    
    def size
      @counters.size
    end
    
  private
  
    def metric_type(metric)
      @cache ||= begin
        all_metrics = @config.dimensions.reduce({}) { |acc, d| acc.merge(d.metrics) }
        Hash[all_metrics.map { |metric_name, message| [message, /\?$/ === message ? :predicate : :numeric] }]
      end
      @cache[metric]
    end
  
    def default_counters(dimension)
      @specials.reduce(@metrics_counters[dimension].dup) do |counters, special|
        counters.merge!(special.default)
      end
    end
  end
end
