# encoding: utf-8


module StreamCounters
  module HashCalculator
    def self.hash(*args)
      args.reduce(0) { |h, p| ((h + p.hash) * 31) % (2**31 - 1) }
    end
  end
  
  class ImmutableList
    include Enumerable
    
    attr_reader :elements
    
    def initialize(*args)
      @elements = args.freeze
    end
    
    def each
      if block_given?
      then @elements.each(&Proc.new)
      else @elements.each
      end
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
      @hash ||= HashCalculator.hash(@meta + @metrics.keys + @metrics.values)
    end
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}(keys: [#{keys.map(&:inspect).join(', ')}], meta: [#{meta.map(&:inspect).join(', ')}], metrics: [#{metrics.values.map(&:inspect).join(', ')}])|
    end
  end
  
  class Metric
    DEFAULT_TYPE = :numeric
    DEFAULT_VALUE = 0
    DEFAULT_IF_MESSAGE = nil
    
    attr_reader :name, :message, :type, :default, :if_message
    
    def initialize(name, message=nil, type=DEFAULT_TYPE, default=DEFAULT_VALUE, if_message=DEFAULT_IF_MESSAGE)
      @name, @message, @type, @default, @if_message = name, message || name, type, default, if_message
    end
    
    def eql?(other)
      self.name == other.name && self.message == other.message && self.type == other.type && self.default == other.default && self.if_message == other.if_message
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@name, @message, @type, @default, @if_message)
    end
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}(name: #{name.inspect}, message: #{message.inspect}, type: #{type.inspect}, default: #{default.inspect}, if_message: #{if_message.inspect})|
    end
  end
end
