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
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}([#{@elements.map(&:inspect).join(', ')}])|
    end
  end
  
  class Keys < ImmutableList
  end
  
  class Dimension < ImmutableList
    attr_reader :meta, :metrics, :base_keys
    alias_method :keys, :elements
    
    def initialize(*args)
      @options = if args.last.is_a?(Hash) then args.pop else {} end
      super(*args)
      @meta = (@options[:meta] || []).freeze
      @metrics = (@options[:metrics] || {}).freeze
      @base_keys = (@options[:base_keys] || []).freeze
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
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}(keys: [#{keys.map(&:inspect).join(', ')}], meta: [#{meta.map(&:inspect).join(', ')}], metrics: [#{metrics.values.map(&:inspect).join(', ')}])|
    end

    def to_h
      hash = {:keys => keys, :base_keys => @base_keys, :metrics => {}}
      @metrics.each do |k, m|
        hash[:metrics][k] = m.to_h
      end
      unless @meta.empty?
        hash[:meta] = @meta
      end
      hash.merge!(super) if defined?(super)
      hash
    end
  end
  
  class Metric
    DEFAULT_TYPE = :numeric
    DEFAULT_VALUE = 0
    DEFAULT_IF_MESSAGE = nil
    DEFAULT_IF_WITH_CONTEXT = nil
    
    attr_reader :name, :message, :type, :default, :if_message, :if_with_context
    
    def initialize(*args)
      if args.length == 1 && args.first.is_a?(Hash)
        hash = args.first
        name = hash[:name]
        message = hash[:message] || name
        type = hash[:type] || DEFAULT_TYPE
        default = hash[:default] || DEFAULT_VALUE
        if_message = hash[:if_message] || DEFAULT_IF_MESSAGE
        if_with_context = hash[:if_with_context] || DEFAULT_IF_WITH_CONTEXT
      else
        name, message, type, default, if_message, if_with_context = args
        type ||= DEFAULT_TYPE
        default ||= DEFAULT_VALUE
        if_message ||= DEFAULT_IF_MESSAGE
        if_with_context ||= DEFAULT_IF_WITH_CONTEXT
      end
      @name, @message, @type, @default, @if_message, @if_with_context = name, message || name, type, default, if_message, if_with_context
    end
    
    def eql?(other)
      self.name == other.name && self.message == other.message && self.type == other.type && self.default == other.default && self.if_message == other.if_message && self.if_with_context == other.if_with_context
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@name, @message, @type, @default, @if_message, @if_with_context)
    end
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}(name: #{name.inspect}, message: #{message.inspect}, type: #{type.inspect}, default: #{default.inspect}, if_message: #{if_message.inspect}, if_with_context: #{if_with_context.inspect})|
    end

    def to_h
      hash = {:name => @name, :message => @message, :type => @type, :default => @default, :if_message => @if_message}
      hash.delete :default if @default.is_a?(Proc)
      hash
    end
  end
end
