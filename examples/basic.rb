$: << File.expand_path('../../lib', __FILE__)

require 'stream_counters'

class Visit
  attr_reader :api_key, :date, :path
  
  def initialize(data={})
    @api_key, @date, @path, @click = data.values_at(:api_key, :date, :path, :click)
  end
  
  def section
    if @path == '/'
    then 'homepage'
    else @path.split('/')[1]
    end
  end
  
  def pageviews
    1
  end
  
  def click?
    @click
  end
end

include StreamCounters::ConfigurationDsl

conf = configuration do
  main_keys :api_key, :date
  dimension :path
  dimension :section
  metric :pageviews
  metric :clicks, :click?, :type => :predicate
end

counters = conf.create_counters(:reducers => {:predicate => lambda { |acc, v| acc + (v ? 1 : 0) }})
counters.count(Visit.new(:api_key => 'ABC', :date => Time.utc(2011, 6, 3), :path => '/blog/article2',       :click => false))
counters.count(Visit.new(:api_key => 'ABC', :date => Time.utc(2011, 6, 3), :path => '/jobs/monkey-handler', :click => false))
counters.count(Visit.new(:api_key => 'DEF', :date => Time.utc(2011, 6, 4), :path => '/',                    :click => false))
counters.count(Visit.new(:api_key => 'DEF', :date => Time.utc(2011, 6, 4), :path => '/blog/article1',       :click => false))
counters.count(Visit.new(:api_key => 'ABC', :date => Time.utc(2011, 6, 4), :path => '/qa/page3',            :click => false))
counters.count(Visit.new(:api_key => 'GHI', :date => Time.utc(2011, 6, 4), :path => '/jobs/sommelier',      :click => true))
counters.count(Visit.new(:api_key => 'ABC', :date => Time.utc(2011, 6, 5), :path => '/',                    :click => true))
counters.each do |data|
  p data
end