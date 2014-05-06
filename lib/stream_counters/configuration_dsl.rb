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
          if args.empty?
            message = name
            options = {}
          elsif args.first.is_a?(Symbol)
            message = args.shift
            options = args.shift || {}
          else
            options = args.shift || {}
          end
          @metrics[name.to_s] = Metric.new(
            name, 
            message || options.fetch(:message, name),
            options.fetch(:type, Metric::DEFAULT_TYPE),
            options.fetch(:default, Metric::DEFAULT_VALUE),
            options.fetch(:if, Metric::DEFAULT_IF_MESSAGE),
            options.fetch(:if_with_context, Metric::DEFAULT_IF_WITH_CONTEXT)
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
          @base_keys = if @prototype then @prototype.base_keys.to_a else [] end
          @metrics = if @prototype then @prototype.metrics.dup else {} end
          @dimensions = if @prototype 
            @prototype.dimensions.map do |d| 
              metrics = d.metrics.reject { |name, m| @metrics.key?(name) }
              DimensionContext.new(*d.keys.dup, 'meta' => d.meta, 'metrics' => metrics, 'base_keys' => @base_keys)
            end
          else
            []
          end
        end
      
        def base_keys(*args)
          @base_keys = args
        end
      
        def dimension(*args, &block)
          dc = DimensionContext.new(*args, 'base_keys' => @base_keys)
          dc.instance_eval(&block) if block_given?
          @dimensions << dc
        end
      
        def build!
          dimensions = @dimensions.reduce({}) do |acc, dc|
            acc[dc.keys] = dc.to_dimension(metrics)
            acc
          end
          Configuration.new(
            Keys.new(*@base_keys),
            metrics,
            dimensions.values,
            self
          )
        end
      end
    
      module DimensionCreation
        def to_dimension(metrics, options={})
          options = options.dup
          options['metrics'] = metrics.merge(self.metrics)
          options['meta'] = self.meta
          options['base_keys'] = self.base_keys
          options['boxed_segments'] = self.boxed_segments
          options['discard_nil_segments'] = self.discard_nil_segments
          Dimension.new(*self.keys.dup, options)
        end
      end
    
      class DimensionContext
        include Metrics
        include DimensionCreation
      
        attr_reader :keys, :base_keys, :boxed_segments
      
        def initialize(*args)
          options = if args.last.is_a?(Hash) then args.pop else {} end
          @keys = (args.map(&:to_s) || [])
          @meta = options.fetch('meta', [])
          @metrics = options.fetch('metrics', {})
          @base_keys = options.fetch('base_keys', [])
          @boxed_segments = options.fetch('boxed_segments', {})
          @discard_nil_segments = options.fetch('discard_nil_segments', false)
        end
      
        def meta(*args)
          if args.empty?
          then @meta
          else @meta = args.map(&:to_s)
          end
        end

        def boxed_segment(*args)
          @boxed_segments[args.first.to_s] = BoxedSegment.new(*args) if args.length >= 3
        end

        def discard_nil_segments(*args)
          if args.empty?
          then @discard_nil_segments
          else
            @discard_nil_segments = case args.first
            when TrueClass,FalseClass
              args.first
            else
              args.map(&:to_s)
            end
          end
        end
      end
    end
  end
end
