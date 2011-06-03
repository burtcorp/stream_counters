# encoding: utf-8


module StreamCounters
  module ConfigurationDsl
    extend self
    
    def counters(prototype=nil, &block)
      cc = DslSupport::ConfigurationContext.new(prototype)
      cc.instance_eval(&block)
      c = cc.build!
      c.extend(ConfigurationMerge)
      c
    end
    
  private
    
    module ConfigurationMerge
      def merge(&block)
        ConfigurationDsl.counters(self, &block)
      end
    end
    
    module DslSupport
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
      
        def initialize(prototype)
          @prototype = prototype
          @main_keys = if @prototype then @prototype.main_keys.to_a else [] end
          @metrics = if @prototype then @prototype.metrics.dup else {} end
          @dimensions = if @prototype 
            @prototype.dimensions.map do |d| 
              metrics = d.metrics.reject { |name, m| @metrics.key?(name) }
              [*d.keys, :meta => d.meta, :metrics => metrics]
            end
          else
            []
          end
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
          dimensions = @dimensions.reduce({}) do |acc, d|
            d = d.dup
            options = d.pop
            keys = d
            options[:metrics] = metrics.merge(options[:metrics])
            d.sort!
            acc[d] = Dimension.new(*d, options)
            acc
          end
          Configuration.new(
            Keys.new(*@main_keys),
            metrics,
            dimensions.values
          )
        end
      end
    
      class DimensionContext
        include Metrics
      
        def initialize
          @meta = []
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
end
