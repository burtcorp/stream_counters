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
      def metric(name, *args)
        @metrics ||= {}
        message = nil
        type = nil
        if args.empty?
          message = name
          type = Metric::DEFAULT_TYPE
          options = {}
        elsif args.first.is_a?(Symbol)
          message = args.shift
          options = args.shift || {}
        else
          options = args.shift || {}
        end
        @metrics[name] = Metric.new(
          name, 
          message || options.fetch(:message, name),
          type || options.fetch(:type, Metric::DEFAULT_TYPE)
        )
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
      end
      
      def main_keys(*args)
        @main_keys = args
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
