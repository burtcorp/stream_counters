# encoding: utf-8


module StreamCounters
  module ConfigurationDsl
    extend self
    
    def counters(&block)
      cc = ConfigurationContext.new
      cc.instance_eval(&block)
      cc.build!
    end
    
  private
    
    module Metrics
      def metric(name, message)
        @metrics ||= {}
        @metrics[name] = Metric.new(name, message)
      end
      
      def metrics
        @metrics || {}
      end
    end
    
    class ConfigurationContext
      include Metrics
      
      def initialize
        @dimensions = []
        @main_keys = []
        @sort_keys = []
      end
      
      def main_keys(*args)
        @main_keys = args
      end
      
      def sort_keys(*args)
        @sort_keys = args
      end
      
      def dimension(*args, &block)
        meta = []
        metrics = {}
        if block_given?
          dc = DimensionContext.new
          dc.instance_eval(&block)
          meta = dc.meta
          metrics = dc.metrics
        end
        @dimensions << [*args, :meta => meta, :metrics => metrics]
      end
      
      def build!
        dimensions = @dimensions.map do |d|
          d = d.dup
          options = d.pop
          options[:metrics] = metrics.merge(options[:metrics])
          d.sort!
          d << options
          Dimension.new(*d)
        end
        Configuration.new(
          Keys.new(*@main_keys),
          Keys.new(*@sort_keys),
          dimensions
        )
      end
    end
    
    class DimensionContext
      include Metrics
      
      def initialize
        @meta = []
        @metrics = {}
      end
      
      def meta(*args)
        if args.empty?
        then @meta
        else @meta = args
        end
      end
    end
  end
end
