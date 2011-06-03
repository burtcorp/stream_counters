$: << File.expand_path('../../lib', __FILE__)

require 'stream_counters'


module DimensionImportance
  # this is the actual DSL method, it will be accesible from within a 
  # dimension block
  def importance(level=nil)
    if level
    then @importance = level
    else @importance
    end
  end
  
  # this intercepts DimensionCreation#to_dimension and adds the :importance 
  # property to the options hash -- the same hash that will be passed to
  # Dimension.new in the default implementation of #to_dimension
  def to_dimension(metrics, options={})
    super(metrics, options.merge(:importance => importance))
  end
end

module DimensionAdditions
  attr_reader :importance
  
  # this intercepts the Dimension constructor and retrieves the :importance
  # property from the options, making it available through the #importance
  # getter defined above
  def initialize(*args)
    @importance = @options[:importance]
    super
  end
end

class StreamCounters::ConfigurationDsl::DslSupport::DimensionContext
  include DimensionImportance
end

class StreamCounters::Dimension
  include DimensionAdditions
end


include StreamCounters::ConfigurationDsl

conf = configuration do
  main_keys :api_key, :date
  dimension :path
  dimension :section do
    importance :high
  end
  metric :pageviews
end

p conf.find_dimension(:section).importance
