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
    attr_reader :meta, :metrics
    alias_method :keys, :elements
    
    def initialize(*args)
      options = if args.last.is_a?(Hash) then args.pop else {} end
      @meta = (options[:meta] || []).freeze
      @metrics = (options[:metrics] || {}).freeze
      super(*args)
    end
    
    def all_keys
      @all_keys ||= (keys + @meta).freeze
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
    
    attr_reader :name, :message, :type
    
    def initialize(name, message=nil, type=DEFAULT_TYPE)
      @name, @message, @type = name, message || name, type
    end
    
    def eql?(other)
      self.name == other.name && self.message == other.message && self.type == other.type
    end
    alias_method :==, :eql?
    
    def hash
      @hash ||= HashCalculator.hash(@name, @message, @type)
    end
    
    def to_s
      @s ||= %|#{self.class.name.split(':').last}(name: #{name.inspect}, message: #{message.inspect}, type: #{type.inspect})|
    end
  end
end