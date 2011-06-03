# encoding: utf-8


module StreamCounters
  module ConfigurationDsl
    extend self
    
    def configuration(prototype=nil, &block)
      cc = DslSupport::ConfigurationContext.new(prototype)
      cc.instance_eval(&block)
      c = cc.build!
      c.extend(ConfigurationMerge)
      c
    end
    
    module ConfigurationMerge
      def merge(&block)
        ConfigurationDsl.configuration(self, &block)
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
              DimensionContext.new(*d.keys, :meta => d.meta, :metrics => metrics)
            end
          else
            []
          end
        end
      
        def main_keys(*args)
          @main_keys = args
        end
      
        def dimension(*args, &block)
          dc = DimensionContext.new(*args)
          dc.instance_eval(&block) if block_given?
          @dimensions << dc
        end
      
        def build!
          dimensions = @dimensions.reduce({}) do |acc, dc|
            acc[dc.keys] = dc.to_dimension(metrics)
            acc
          end
          Configuration.new(
            Keys.new(*@main_keys),
            metrics,
            dimensions.values
          )
        end
      end
    
      module DimensionCreation
        def to_dimension(metrics, options={})
          options = options.dup
          options[:metrics] = metrics.merge(self.metrics)
          options[:meta] = self.meta
          Dimension.new(*self.keys, options)
        end
      end
    
      class DimensionContext
        include Metrics
        include DimensionCreation
      
        attr_reader :keys
      
        def initialize(*args)
          options = if args.last.is_a?(Hash) then args.pop else {} end
          @keys = (args || []).sort
          @meta = options.fetch(:meta, [])
          @metrics = options.fetch(:metrics, {})
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
