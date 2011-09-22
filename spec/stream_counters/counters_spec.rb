# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  class Item
    attr_reader :xyz, :abc, :def, :ghi, :some_count, :another_number
    
    def initialize(values)
      @xyz = values[:xyz]
      @abc = values[:abc]
      @def = values[:def]
      @ghi = values[:ghi]
      @some_count = values[:some_count]
      @another_number = values[:another_number]
    end
  end
  
  describe Counters do
    include ConfigurationDsl

    class Special
      def initialize(keys, dimension)
        @dimension = dimension
        reset
      end
      def reset; @values = {}; end
      def count(item)
        segment = @dimension.keys.map { |key| item.send(key) }
        value_for_seg = (@values[segment] ||= {:xor => 0})
        value_for_seg[:xor] += 1 if (item.some_count == 1) ^ (item.another_number == 1)
      end
      def value(segment)
        @values[segment]
      end
    end

    before do
      @config1 = configuration do
        base_keys :xyz
        dimension :abc
        dimension :def
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
      @config2 = configuration do
        base_keys :xyz
        dimension :abc
        dimension :def, :ghi
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
      @config3 = configuration do
        base_keys :xyz
        dimension :abc
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end
    
    describe '#count/#get' do
      it 'sums the total of each metric given each segment of each dimension' do
        counters = Counters.new(@config1)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => 99)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number =>  1)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => 45)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 8, :another_sum => 49},
          ['world'] => {:some_sum => 4, :another_sum => 99}
        }
      end
      
      it 'handles dimension combinations' do
        counters = Counters.new(@config2)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config2.find_dimension(:def, :ghi)).should == {
          ['foo', 'plink'] => {:some_sum => 2, :another_sum => 0},
          ['bar', 'plonk'] => {:some_sum => 0, :another_sum => 1},
          ['bar', 'plunk'] => {:some_sum => 0, :another_sum => 0}
        }
      end
    
      it 'delegates special metrics' do
        counters = Counters.new(@config3, :specials => [Special])
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config3.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 2, :another_sum => 0, :xor => 2},
          ['world'] => {:some_sum => 0, :another_sum => 1, :xor => 1}
        }
      end
      
      it 'uses a metric\'s default value from the configuration (when it\'s an integer)' do
        @config1 = @config1.merge do
          metric :another_sum, :another_number, :default => 3
        end
        counters = Counters.new(@config1)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => 99)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number =>  1)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => 45)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 8, :another_sum =>  52},
          ['world'] => {:some_sum => 4, :another_sum => 102}
        }
      end

      it 'uses a metric\'s default value from the configuration (when it\'s a list)' do
        @config1 = @config1.merge do
          metric :another_sum, :another_number, :default => []
        end
        counters = Counters.new(@config1)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => [ 3])
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => [99])
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number => [ 1])
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => [45])
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 8, :another_sum => [3, 1, 45]},
          ['world'] => {:some_sum => 4, :another_sum => [99]}
        }
      end

      it 'uses a metric\'s default value from the configuration (when it responds to :call)' do
        @config1 = @config1.merge do
          metric :another_sum,             :another_number, :default => lambda {                     [] }, :type => :list
          metric :another_sum_with_1_args, :another_number, :default => lambda { |metric|            [] }, :type => :list
          metric :another_sum_with_2_args, :another_number, :default => lambda { |metric, dimension| [] }, :type => :list
        end
        counters = Counters.new(@config1, :reducers => {:list => lambda { |acc, x| acc << x }})
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => 99)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number =>  1)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => 45)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 8, :another_sum => [3, 1, 45], :another_sum_with_1_args => [3, 1, 45], :another_sum_with_2_args => [3, 1, 45]},
          ['world'] => {:some_sum => 4, :another_sum => [99], :another_sum_with_1_args => [99], :another_sum_with_2_args => [99]}
        }
      end

      it 'calls a metric\'s default value with metric and dimension if it responds to :call' do
        default_value = double('default value')
        default_value.stub(:respond_to?).with(:call).and_return(true)
        default_value.stub(:arity).and_return(2)
        default_value.should_receive(:call) do |metric, dimension|
          metric.name.should == :another_sum
          dimension.keys.should == [:abc]
          []
        end
        @config1 = configuration do
          base_keys :xyz
          dimension :abc
          metric :another_sum, :another_number, :default => default_value, :type => :list
        end
        counters = Counters.new(@config1, :reducers => {:list => lambda { |acc, x| acc << x }})
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        counters.count(item1)
      end

      it 'raises an error when callable default value has arity > 2' do
        @config1 = @config1.merge do
          metric :another_sum, :another_number, :default => lambda { |metric, dimension, superfluous| [] }
        end
        proc {
          counters = Counters.new(@config1)
          item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
          counters.count(item1)
        }.should raise_error(ArgumentError)
      end
      
      it 'can be configured to use a custom reducer function for a metric type' do
        @config1 = @config1.merge do
          metric :another_sum, :another_number, :default => true, :type => :boolean
        end
        counters = Counters.new(@config1, :reducers => {:boolean => lambda { |acc, x| acc && x }})
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => true)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => true)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number => false)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => true)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 8, :another_sum => false},
          ['world'] => {:some_sum => 4, :another_sum => true}
        }
      end

      it 'only counts items with truthy :if message, if not nil for a metric' do
        @config1 = configuration do
          base_keys :xyz
          dimension :abc
          metric :some_sum, :some_count, :if => :another_number
          metric :another_sum, :some_count, :if => nil
        end
        counters = Counters.new(@config1, :reducers => {:boolean => lambda { |acc, x| acc && x }})
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => true)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => true)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number => false)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => true)
        item5 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 28, :another_number => false)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.count(item5)
        counters.get(['first'], @config1.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 2, :another_sum => 8},
          ['world'] => {:some_sum => 4, :another_sum => 32}
        }
      end
    end
  
    describe '#each' do
      it 'yields each key/dimension/segment combination' do
        counters = Counters.new(@config2, :specials => [Special])
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        datas = []
        dimensions = []
        counters.each { |data, dimension| datas << data; dimensions << dimension }
        datas.should == [
          {:xyz => 'first', :abc => 'hello',                  :some_sum => 2, :another_sum => 0, :xor => 2},
          {:xyz => 'first', :abc => 'world',                  :some_sum => 0, :another_sum => 1, :xor => 1},
          {:xyz => 'first', :def => 'foo',   :ghi => 'plink', :some_sum => 2, :another_sum => 0, :xor => 2},
          {:xyz => 'first', :def => 'bar',   :ghi => 'plonk', :some_sum => 0, :another_sum => 1, :xor => 1},
          {:xyz => 'first', :def => 'bar',   :ghi => 'plunk', :some_sum => 0, :another_sum => 0, :xor => 0}
        ]
        dimensions.should == [
          @config2.find_dimension(:abc),
          @config2.find_dimension(:abc),
          @config2.find_dimension(:def, :ghi),
          @config2.find_dimension(:def, :ghi),
          @config2.find_dimension(:def, :ghi)
        ]
      end
    end
  end
end
