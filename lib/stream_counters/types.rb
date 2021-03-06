# encoding: utf-8


module StreamCounters
  module HashCalculator
    def self.hash(*args)
      h = 0
      args.each { |p| h = (h & 33554431) * 31 ^ p.hash }
      h
    end
  end
  
  class ImmutableList
    include Enumerable
    
    attr_reader :elements
    
    def initialize(*args)
      @elements = args.freeze
    end

    def each(&block)
      @elements.each(&block)
    end

    def eql?(other)
      case other
      when Array then @elements == other
      else self.elements == other.elements
      end
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@elements)
    end
    
    def to_ary
      @elements
    end
    alias_method :to_a, :to_ary
    
    def inspect
      @i ||= %|#{self.class.name.split(':').last}([#{@elements.map(&:inspect).join(', ')}])|
    end
    alias_method :to_s, :inspect
  end
  
  class Keys < ImmutableList
  end
  
  class Dimension < ImmutableList
    attr_reader :meta, :metrics, :base_keys, :boxed_segments, :discard_nil_segments
    alias_method :keys, :elements
    
    def initialize(*args)
      @options = if args.last.is_a?(Hash) then args.pop else {} end
      super(*args)
      @meta = (@options['meta'] || []).map(&:to_s).freeze
      @metrics = (@options['metrics'] || {}).freeze
      @base_keys = (@options['base_keys'].map(&:to_s) || []).freeze
      @boxed_segments = (@options['boxed_segments'] || []).freeze
      @discard_nil_segments = (@options['discard_nil_segments'] || false).freeze
    end
    
    def eql?(other)
      if @meta.empty? && @metrics.empty? && (other.is_a?(Array) || (other.meta.empty? && other.metrics.empty?))
      then super(other)
      else super(other) && self.meta == other.meta && self.metrics == other.metrics
      end
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@meta, @metrics)
    end
    
    def inspect
      @i ||= %|#{self.class.name.split(':').last}(keys: [#{keys.map(&:inspect).join(', ')}], meta: [#{meta.map(&:inspect).join(', ')}], metrics: [#{metrics.values.map(&:inspect).join(', ')}])|
    end
    alias_method :to_s, :inspect

    def to_h
      hash = {'keys' => keys, 'base_keys' => @base_keys, 'metrics' => {}}
      @metrics.each do |k, m|
        hash['metrics'][k] = m.to_h
      end
      unless @meta.empty?
        hash['meta'] = @meta
      end
      unless @boxed_segments.empty?
        hash['boxed_segments'] = @boxed_segments.is_a?(Hash) ? @boxed_segments.values.map(&:to_h) :  @boxed_segments
      end
      hash.merge!(super) if defined?(super)
      hash
    end
  end
  
  class Metric
    DEFAULT_TYPE = 'numeric'
    DEFAULT_VALUE = 0
    DEFAULT_IF_MESSAGE = nil
    DEFAULT_IF_WITH_CONTEXT = nil
    
    attr_reader :name, :message, :type, :default, :if_message, :if_with_context
    
    def initialize(*args)
      if args.length == 1 && args.first.is_a?(Hash)
        hash = args.first
        name = hash['name']
        message = hash['message']
        type = hash['type'] || DEFAULT_TYPE
        default = hash['default'] || DEFAULT_VALUE
        if_message = hash['if_message'] || DEFAULT_IF_MESSAGE
        if_with_context = hash['if_with_context'] || DEFAULT_IF_WITH_CONTEXT
      else
        name, message, type, default, if_message, if_with_context = args
        type ||= DEFAULT_TYPE
        default ||= DEFAULT_VALUE
        if_message ||= DEFAULT_IF_MESSAGE
        if_with_context ||= DEFAULT_IF_WITH_CONTEXT
      end
      message ||= name
      name = name.to_s if name
      message = message.to_s if message
      type = type.to_s if type
      if_message = if_message.to_s if if_message
      if_with_context = if_with_context.to_s if if_with_context
      @name, @message, @type, @default, @if_message, @if_with_context = name, message || name, type, default, if_message, if_with_context
    end
    
    def eql?(other)
      self.name == other.name && self.message == other.message && self.type == other.type && self.default == other.default && self.if_message == other.if_message && self.if_with_context == other.if_with_context
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@name, @message, @type, @default, @if_message, @if_with_context)
    end
    
    def inspect
      @i ||= %|#{self.class.name.split(':').last}(name: #{name.inspect}, message: #{message.inspect}, type: #{type.inspect}, default: #{default.inspect}, if_message: #{if_message.inspect}, if_with_context: #{if_with_context.inspect})|
    end
    alias_method :to_s, :inspect

    def to_h
      hash = {'name' => @name, 'message' => @message, 'type' => @type, 'default' => @default, 'if_message' => @if_message}
      hash.delete 'default' if @default.is_a?(Proc)
      hash
    end
  end

  class BoxedSegment
    attr_reader :name, :metric, :boxes

    def initialize(*args)
      if args.length == 1 && args.first.is_a?(Hash)
        hash = args.first
        name = hash['name']
        metric = hash['metric']
        boxes = hash['boxes']
        scale = hash['scale']
      else
        name, metric, boxes, args = args
        scale = args[:scale] if args && args[:scale]
      end
      @name = name.to_s
      @metric = metric.to_s
      @boxes = boxes || []
      @scale = scale || 1
    end

    def box(value)
      return nil if @boxes.empty? || value.nil?
      value *= @scale if @scale != 1
      return @boxes.first if value < @boxes[1]
      return @boxes.last if value >= @boxes.last
      @boxes.each_cons(2) do |low, high|
        return low if value < high
      end
    end

    def eql?(other)
      self.name == other.name && self.metric == other.metric && self.boxes == other.boxes
    end
    alias_method :==, :eql?

    def to_h
      hash = {
        'name' => @name,
        'metric' => @metric,
        'boxes' => @boxes,
      }
      hash['scale'] = @scale if @scale != 1
      hash
    end
  end
end
