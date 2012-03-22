# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  class Item
    attr_reader :xyz, :abc, :def, :ghi, :some_count, :meta1, :number, :boxed_number
    
    def initialize(values)
      @xyz = values[:xyz]
      @abc = values[:abc]
      @def = values[:def]
      @ghi = values[:ghi]
      @meta1 = values[:meta1]
      @some_count = values[:some_count]
      @another_number = values[:another_number]
      @number = values[:number]
      @boxed_number = values[:boxed_number]
    end
    
    def another_number
      @another_number
    end
    
    def goodbye(segment_map = nil)
      segment_map[:abc] == "goodbye"
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
      @config4 = configuration do
        base_keys :xyz
        dimension :abc do
          meta :meta1
        end
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
     @config5 = configuration do
        base_keys :xyz
        dimension :abc
        dimension :def
        dimension :abc, :def
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
      @boxed_config = configuration do
        base_keys :xyz
        dimension :boxed_number do
          boxed_segment :boxed_number, :number, [1, 5, 10]
        end
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
      
      it 'handles meta (overrides nil-values if non-nil values exist)' do
        counters = Counters.new(@config4)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0, :meta1 => nil)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1, :meta1 => 'meta_world')
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0, :meta1 => 'meta_hello')
        item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0, :meta1 => 'meta_hello')
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config4.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 2, :another_sum => 0, :meta1 => 'meta_hello'},
          ['world'] => {:some_sum => 0, :another_sum => 1, :meta1 => 'meta_world'}
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
      
      it 'sends segment values to if method for verification' do
        @config1 = configuration do
          base_keys :xyz
          dimension :abc
          metric :some_sum, :some_count, :if_with_context => :goodbye
          metric :another_sum, :some_count, :if => nil
        end
        counters = Counters.new(@config1, :reducers => {:boolean => lambda { |acc, x| acc && x }})
        item1 = Item.new(:xyz => 'first', :abc => ['hello', 'goodbye'], :def => 'foo', :some_count => 1, :another_number => true)
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
          ['hello'] => {:some_sum => 0, :another_sum => 8},
          ['world'] => {:some_sum => 0, :another_sum => 32},
          ['goodbye'] => {:some_sum => 1, :another_sum => 1}
        }
      end

      it 'boxes segments of asked, overrides already boxed numbers' do
        counters = Counters.new(@boxed_config)
        item1 = Item.new(:xyz => 'first', :number => 0.5, :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :number => 2, :some_count => 1, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :number => 5, :some_count => 0, :another_number => 1)
        item4 = Item.new(:xyz => 'first', :number => 6, :some_count => 1, :another_number => 1)
        item5 = Item.new(:xyz => 'first', :number => 7, :some_count => 1, :another_number => 0)
        item6 = Item.new(:xyz => 'first', :number => 11, :some_count => 1, :another_number => 1)
        item6 = Item.new(:xyz => 'first', :number => 11, :some_count => 1, :another_number => 1)
        item7 = Item.new(:xyz => 'first', :number => 7, :boxed_number => 7, :some_count => 1, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.count(item5)
        counters.count(item6)
        counters.count(item7)
        counters.get(['first'], @boxed_config.find_dimension(:boxed_number)).should == {
          [1] => {:some_sum => 2, :another_sum => 1},
          [5] => {:some_sum => 3, :another_sum => 2},
          [10] => {:some_sum => 1, :another_sum => 1}
        }
      end
      
      it 'counts set/list values towards multiple segments' do
        counters = Counters.new(@config3)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => ['hello', 'world', 'apa'], :def => 'foo', :ghi => 'plink', :some_count => 2, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config3.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 3, :another_sum => 0},
          ['world'] => {:some_sum => 2, :another_sum => 1},
          ['apa'] =>   {:some_sum => 2, :another_sum => 0}
        }
      end
      
      it 'counts hash values towards multiple segments, with the hash values determining the weights' do
        counters = Counters.new(@config3)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => {'hello' => 0.6, 'world' => 0.5}, :def => 'foo', :ghi => 'plink', :some_count => 2, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config3.find_dimension(:abc)).should == {
          ['hello'] => {:some_sum => 1 + 2 * 0.6, :another_sum => 0.0},
          ['world'] => {:some_sum => 2 * 0.5, :another_sum => 1.0}
        }
      end

      it 'counts hash values towards multiple segments, with the hash values determining the weights (with dimension combinations)' do
        counters = Counters.new(@config5)
        item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => 'plink', :some_count => 1, :another_number => 0)
        item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :ghi => 'plonk', :some_count => 0, :another_number => 1)
        item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :ghi => 'plunk', :some_count => 0, :another_number => 0)
        item4 = Item.new(:xyz => 'first', :abc => {'hello' => 0.6, 'world' => 0.5}, :def => {'foo' => 0.1, 'bar' => 0.2}, :ghi => 'plink', :some_count => 2, :another_number => 0)
        counters.count(item1)
        counters.count(item2)
        counters.count(item3)
        counters.count(item4)
        counters.get(['first'], @config5.find_dimension(:abc, :def)).should == {
          ['hello', 'foo'] => {:some_sum => 1 + 0.6 * 0.1 * 2, :another_sum => 0.0},
          ['hello', 'bar'] => {:some_sum => 0.6 * 0.2 * 2,     :another_sum => 0.0},
          ['world', 'foo'] => {:some_sum => 0.5 * 0.1 * 2,     :another_sum => 0.0},
          ['world', 'bar'] => {:some_sum => 0.5 * 0.2 * 2,     :another_sum => 1.0}
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
    
    describe '#product flatter' do
      before do
        @counter = Counters.new(@config1)
      end
      it 'wraps single segment values in an array' do
        @counter.product_flatter(["ad_id_ad_id", "domain_domain_domain"]).should == [["ad_id_ad_id", "domain_domain_domain"]]
      end

      it 'translates semi-complex segment values into multiple ordinary ones' do
        @counter.product_flatter([["mouseEnter", "mouseExit"]]).should == [["mouseEnter"], ["mouseExit"]]
      end
      
      it 'translates hash segment values into their keys' do
        @counter.product_flatter([{"mouseEnter" => 0.4, "mouseExit" => 1.0}]).should == [[{"mouseEnter" => 0.4}], [{"mouseExit" => 1.0}]]
      end
      
      it 'translates complex segment values into multiple ordinary ones by permutation' do
        @counter.product_flatter([["mouseEnter", "mouseExit"], 'apa']).should == [["mouseEnter", 'apa'], ["mouseExit", 'apa']]
      end

      it 'translates complex hash segment values into multiple ordinary ones by permutation' do
        @counter.product_flatter([{"mouseEnter" => 0.4, "mouseExit" => 0.7}, 'apa']).should == [[{"mouseEnter" => 0.4}, 'apa'], [{"mouseExit" => 0.7}, 'apa']]
      end

      it 'translates complex segment values into multiple ordinary ones by permutation' do
        @counter.product_flatter([["mouseEnter", "mouseExit"], ['apa', 'bepa']]).should == [["mouseEnter", 'apa'], ["mouseEnter", 'bepa'], ["mouseExit", 'apa'], ["mouseExit", 'bepa']]
      end

      it 'tripple is just too much' do
        expect { @counter.product_flatter([["mouseEnter", "mouseExit"], 'apa', [:a, :b]])}.to raise_error ArgumentError
      end
    end

    describe '#empty?' do
      before do
        @counters = Counters.new(@config1)
        @item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        @item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => 99)
        @item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number =>  1)
        @item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => 45)
      end

      it 'returns true if no items have been counted' do
        @counters.should be_empty
      end

      it 'returns false if there are items' do
        @counters.count(@item1)
        @counters.count(@item2)
        @counters.should_not be_empty
      end

      it 'returns true if it has just been reset' do
        @counters.count(@item1)
        @counters.count(@item2)
        @counters.reset
        @counters.should be_empty
      end
    end

    describe '#items_counted' do
      before do
        @counters = Counters.new(@config1)
        @item1 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        @item2 = Item.new(:xyz => 'first', :abc => 'world', :def => 'bar', :some_count => 4, :another_number => 99)
        @item3 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'bar', :some_count => 6, :another_number =>  1)
        @item4 = Item.new(:xyz => 'first', :abc => 'hello', :def => 'baz', :some_count => 1, :another_number => 45)
      end

      it 'returns the number of items counted' do
        @counters.count(@item1)
        @counters.count(@item2)
        @counters.count(@item3)
        @counters.count(@item4)
        @counters.items_counted.should == 4
      end

      it 'returns the number of items counted since the last reset' do
        @counters.count(@item1)
        @counters.count(@item2)
        @counters.reset
        @counters.count(@item3)
        @counters.count(@item4)
        @counters.items_counted.should == 2
      end
    end
  end
end
