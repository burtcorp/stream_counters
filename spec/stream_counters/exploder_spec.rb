# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  class Special
    def initialize(keys, dimension)
      @dimension = dimension
      reset
    end
    def reset; @values = {}; end
    def count(item)
      segment = @dimension.keys.map { |key| item.send(key) }
      value_for_seg = (@values[segment] ||= {'xor' => 0})
      value_for_seg['xor'] += 1 if (item.some_count == 1) ^ (item.another_number == 1)
    end
    def value(segment)
      @values[segment]
    end
  end

  describe Exploder do
    include ConfigurationDsl

    let :basic_config do
      configuration do
        base_keys :xyz
        dimension :abc
        dimension :def
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end

    let :config_with_dimension_combination do
      configuration do
        base_keys :xyz
        dimension :abc
        dimension :def, :ghi
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end

    let :config_with_meta do
      configuration do
        base_keys :xyz
        dimension :abc do
          meta :meta1
        end
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end

    let :config_with_default_scalar do
      basic_config.merge do
        metric :another_sum, :another_number, :default => 3
      end
    end

    let :config_with_default_list do
      basic_config.merge do
        metric :another_sum, :another_number, :default => []
      end
    end

    let :config_with_default_proc do
      basic_config.merge do
        metric :another_sum,             :another_number, :default => lambda {                     [ ] }
        metric :another_sum_with_1_args, :another_number, :default => lambda { |metric|            [1] }
        metric :another_sum_with_2_args, :another_number, :default => lambda { |metric, dimension| [2] }
      end
    end

    let :config_with_reducer do
      basic_config.merge do
        metric :another_sum, :another_number, :default => 0, :type => :boolean
      end
    end

    let :config_with_discard_nil do
      configuration do
        base_keys :xyz
        dimension :abc do
          discard_nil_segments true
        end
        dimension :abc, :def do
          discard_nil_segments true
        end
        dimension :def do
          discard_nil_segments false
        end
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end

    describe '#explode' do
      it 'explodes an item into segment operations' do
        item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
        first_dim = basic_config.find_dimension('abc')
        second_dim = basic_config.find_dimension('def')
        result = Exploder.new(basic_config).explode(item)
        result.should == {
          first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}],
          second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}]
        }
      end

      context 'with a dimension with two properties' do
        it 'explodes an item into segment operations' do
          item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :ghi => nil, :some_count => 1, :another_number =>  3)
          first_dim = config_with_dimension_combination.find_dimension('abc')
          second_dim = config_with_dimension_combination.find_dimension('def', 'ghi')
          result = Exploder.new(config_with_dimension_combination).explode(item)
          result.should == {
             first_dim  => [{'abc' => 'hello',              'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}],
             second_dim => [{'def' => 'foo',   'ghi' => nil, 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}]
          }
        end
      end

      context 'with specials' do
        it 'explodes an item into segment operations' do
          item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number =>  3)
          first_dim = basic_config.find_dimension('abc')
          second_dim = basic_config.find_dimension('def')
          result = Exploder.new(basic_config, :specials => [Special]).explode(item)
          result.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3, 'xor' => 1}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3, 'xor' => 1}]
          }
        end
      end

      context 'with meta properties' do
        it 'explodes an item into segment operations' do
          item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => 3, :meta1 => 'hello')
          first_dim = config_with_meta.find_dimension('abc')
          result = Exploder.new(config_with_meta).explode(item)
          result.should == {
            first_dim => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3, 'meta1' => 'hello'}]
          }
        end
      end

      context 'with default metric values' do
        it 'uses the default value when the value is a scalar' do
          item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => nil)
          first_dim = config_with_default_scalar.find_dimension('abc')
          second_dim = config_with_default_scalar.find_dimension('def')
          result = Exploder.new(config_with_default_scalar).explode(item)
          result.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 3}]
          }
        end

        it 'uses the default value when the value is a mutable object' do
          exploder = Exploder.new(config_with_default_list)
          first_dim = config_with_default_list.find_dimension('abc')
          second_dim = config_with_default_list.find_dimension('def')
          item1 = stub(:item1, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => nil)
          item2 = stub(:item2, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => nil)
          result1 = exploder.explode(item1)
          result2 = exploder.explode(item2)
          result1.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => []}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => []}]
          }
          result2[first_dim].first['another_sum'].should_not equal(result1[first_dim].first['another_sum'])
        end

        it 'calls a proc given as default value' do
          item = stub(:item, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => nil)
          first_dim = config_with_default_proc.find_dimension('abc')
          second_dim = config_with_default_proc.find_dimension('def')
          result = Exploder.new(config_with_default_proc).explode(item)
          result.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => [], 'another_sum_with_1_args' => [1], 'another_sum_with_2_args' => [2]}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => [], 'another_sum_with_1_args' => [1], 'another_sum_with_2_args' => [2]}]
          }
        end
      end

      context 'with custom reducers' do
        it 'calls the reducer with the default value, and the segment value' do
          exploder = Exploder.new(config_with_reducer, :reducers => {'boolean' => lambda { |acc, x, multiplier| acc + (x ? 1 : 0) * multiplier }})
          first_dim = config_with_reducer.find_dimension('abc')
          second_dim = config_with_reducer.find_dimension('def')
          item1 = stub(:item1, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => true)
          item2 = stub(:item2, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => false)
          result1 = exploder.explode(item1)
          result2 = exploder.explode(item2)
          result1.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 1}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 1}]
          }
          result2.should == {
            first_dim  => [{'abc' => 'hello', 'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 0}],
            second_dim => [{'def' => 'foo',   'xyz' => 'first', 'some_sum' => 1, 'another_sum' => 0}]
          }
        end
      end

      context 'when using discard nil segments' do
        it 'does not return segments where discard_nil_segments is true and a value for one of the segment keys is nil' do
          exploder = Exploder.new(config_with_discard_nil)
          first_dim = config_with_discard_nil.find_dimension('abc')
          second_dim = config_with_discard_nil.find_dimension('abc', 'def')
          third_dim = config_with_discard_nil.find_dimension('def')
          item1 = stub(:item1, :xyz => 'first', :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => 0)
          item2 = stub(:item2, :xyz => 'first', :abc => 'hello', :def => nil,   :some_count => 1, :another_number => 0)
          item3 = stub(:item3, :xyz => 'first', :abc => nil,     :def => nil,   :some_count => 1, :another_number => 1)
          item4 = stub(:item4, :xyz => nil,     :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => 1)
          result1 = exploder.explode(item1)
          result2 = exploder.explode(item2)
          result3 = exploder.explode(item3)
          result4 = exploder.explode(item4)
          result1.should == {
            first_dim  => [{'xyz' => 'first', 'abc' => 'hello',                'some_sum' => 1, 'another_sum' => 0}],
            second_dim => [{'xyz' => 'first', 'abc' => 'hello', 'def' => 'foo', 'some_sum' => 1, 'another_sum' => 0}],
            third_dim  => [{'xyz' => 'first',                  'def' => 'foo', 'some_sum' => 1, 'another_sum' => 0}]
          }
          result2.should == {
            first_dim  => [{'xyz' => 'first', 'abc' => 'hello',              'some_sum' => 1, 'another_sum' => 0}],
            third_dim  => [{'xyz' => 'first',                  'def' => nil, 'some_sum' => 1, 'another_sum' => 0}]
          }
          result3.should == {
            third_dim => [{'xyz' => 'first', 'def' => nil, 'some_sum' => 1, 'another_sum' => 1}]
          }
          result4.should == {}
        end
      end

      context 'with multi-segment keys' do
        it 'permutes dimension keys and counts items towards all combinations' do
          exploder = Exploder.new(basic_config)
          first_dim = basic_config.find_dimension('abc')
          second_dim = basic_config.find_dimension('def')
          item = stub(:item, :xyz => 'first', :abc => ['hello', 'world'], :def => 'foo', :some_count => 1, :another_number => 0)
          result = exploder.explode(item)
          result.should == {
            first_dim  => [
              {'xyz' => 'first', 'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'first', 'abc' => 'world', 'some_sum' => 1, 'another_sum' => 0}
            ],
            second_dim => [
              {'xyz' => 'first', 'def' => 'foo', 'some_sum' => 1, 'another_sum' => 0}
            ]
          }
        end

        it 'permutes base keys and counts items towards all combinations' do
          exploder = Exploder.new(basic_config)
          first_dim = basic_config.find_dimension('abc')
          second_dim = basic_config.find_dimension('def')
          item = stub(:item, :xyz => ['first', 'second'], :abc => 'hello', :def => 'foo', :some_count => 1, :another_number => 0)
          result = exploder.explode(item)
          result.should == {
            first_dim  => [
              {'xyz' => 'first',  'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0}
            ],
            second_dim => [
              {'xyz' => 'first',  'def' => 'foo', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'def' => 'foo', 'some_sum' => 1, 'another_sum' => 0}
            ]
          }
        end

        it 'permutes all keys and counts items towards all combinations' do
          exploder = Exploder.new(config_with_dimension_combination)
          first_dim = config_with_dimension_combination.find_dimension('abc')
          second_dim = config_with_dimension_combination.find_dimension('def', 'ghi')
          item = stub(:item, :xyz => ['first', 'second', 'third'], :abc => ['hello', 'world'], :def => 'foo', :ghi => ['one', 'two', 'three'], :some_count => 1, :another_number => 0)
          result = exploder.explode(item)
          result.should == {
            first_dim  => [
              {'xyz' => 'first',  'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'first',  'abc' => 'world', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'abc' => 'world', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'third',  'abc' => 'hello', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'third',  'abc' => 'world', 'some_sum' => 1, 'another_sum' => 0}
            ],
            second_dim => [
              {'xyz' => 'first',  'def' => 'foo', 'ghi' => 'one',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'first',  'def' => 'foo', 'ghi' => 'two',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'first',  'def' => 'foo', 'ghi' => 'three', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'def' => 'foo', 'ghi' => 'one',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'def' => 'foo', 'ghi' => 'two',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'second', 'def' => 'foo', 'ghi' => 'three', 'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'third',  'def' => 'foo', 'ghi' => 'one',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'third',  'def' => 'foo', 'ghi' => 'two',   'some_sum' => 1, 'another_sum' => 0},
              {'xyz' => 'third',  'def' => 'foo', 'ghi' => 'three', 'some_sum' => 1, 'another_sum' => 0}
            ]
          }
        end
      end

      context 'with :if' do
        let :config_with_if do
          configuration do
            base_keys :xyz
            dimension :abc
            metric :some_sum, :some_count, :if => :some_predicate
          end
        end

        let :config_with_if_with_context do
          configuration do
            base_keys :xyz
            dimension :abc
            metric :some_sum, :some_count, :if_with_context => :some_predicate
          end
        end

        it 'counts only items where the :if predicate returns a truthy value' do
          first_dim = config_with_if.find_dimension('abc')
          exploder = Exploder.new(config_with_if)
          item1 = stub(:item, :xyz => 'first', :abc => 'foo', :some_count => 3, :some_predicate => true)
          item2 = stub(:item, :xyz => 'first', :abc => 'bar', :some_count => 2, :some_predicate => 'yes')
          item3 = stub(:item, :xyz => 'first', :abc => 'baz', :some_count => 1, :some_predicate => nil)
          result1 = exploder.explode(item1)
          result2 = exploder.explode(item2)
          result3 = exploder.explode(item3)
          result1.should == {first_dim => [{'xyz' => 'first', 'abc' => 'foo', 'some_sum' => 3}]}
          result2.should == {first_dim => [{'xyz' => 'first', 'abc' => 'bar', 'some_sum' => 2}]}
          result3.should == {first_dim => [{'xyz' => 'first', 'abc' => 'baz', 'some_sum' => 0}]}
        end

        it 'passes the segment to the :if_with_context predicate and counts only items where it returns a truthy value' do
          first_dim = config_with_if_with_context.find_dimension('abc')
          exploder = Exploder.new(config_with_if_with_context)
          item1 = stub(:item, :xyz => 'first', :abc => 'foo', :some_count => 3)
          item2 = stub(:item, :xyz => 'first', :abc => 'bar', :some_count => 2)
          item3 = stub(:item, :xyz => 'first', :abc => 'baz', :some_count => 1)
          item1.should_receive(:some_predicate) do |segment|
            segment['xyz'].should == 'first'
            segment['abc'].should == 'foo'
            segment.should_not have_key(:some_sum)
            true
          end
          item2.should_receive(:some_predicate) do |segment|
            segment['xyz'].should == 'first'
            segment['abc'].should == 'bar'
            segment.should_not have_key(:some_sum)
            true
          end
          item3.should_receive(:some_predicate) do |segment|
            segment['xyz'].should == 'first'
            segment['abc'].should == 'baz'
            segment.should_not have_key(:some_sum)
            false
          end
          result1 = exploder.explode(item1)
          result2 = exploder.explode(item2)
          result3 = exploder.explode(item3)
          result1.should == {first_dim => [{'xyz' => 'first', 'abc' => 'foo', 'some_sum' => 3}]}
          result2.should == {first_dim => [{'xyz' => 'first', 'abc' => 'bar', 'some_sum' => 2}]}
          result3.should == {first_dim => [{'xyz' => 'first', 'abc' => 'baz', 'some_sum' => 0}]}
        end

        it 'calls the :if/:if_with_context predicates after permutation' do
          first_dim = config_with_if_with_context.find_dimension('abc')
          exploder = Exploder.new(config_with_if_with_context)
          item = stub(:item, :xyz => 'first', :abc => ['foo', 'oof'], :some_count => 3)
          item.should_receive(:some_predicate) { |segment| segment['abc'] == 'oof' }.twice
          result = exploder.explode(item)
          result.should == {first_dim => [
            {'xyz' => 'first', 'abc' => 'foo', 'some_sum' => 0},
            {'xyz' => 'first', 'abc' => 'oof', 'some_sum' => 3}
          ]}
        end
      end
    end
  end
end