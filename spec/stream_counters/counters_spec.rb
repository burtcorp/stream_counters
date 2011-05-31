# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  describe Counters do
    include ConfigurationDsl
    
    before do
      @config1 = counters do
        main_keys :master
        dimension :dim1
        dimension :dim2
        default_metrics :met1s => :met1?, :met2s => :met2?
      end
      @config2 = counters do
        main_keys :master
        dimension :dim1
        dimension :dim2
        default_metrics :met1 => :met1, :met2 => :met2
      end
      @config3 = counters do
        main_keys :master
        dimension :dim1
        dimension :dim2, :dim3
        default_metrics :met1s => :met1?, :met2s => :met2?
      end
      @config4 = counters do
        main_keys :master
        dimension :dim1
        default_metrics :met1s => :met1?, :met2s => :met2?
      end
    end
    
    describe '#handle_item/#get' do
      it 'counts the number of occurrences of each predicate metric given each segment of each dimension' do
        counters = Counters.new(@config1)
        item1 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :met1? => true,  :met2? => false)
        item2 = stub(:master => 'first', :dim1 => 'world', :dim2 => 'bar', :met1? => false, :met2? => true)
        item3 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'bar', :met1? => false, :met2? => false)
        item4 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'baz', :met1? => true,  :met2? => false)
        counters.handle_item(item1)
        counters.handle_item(item2)
        counters.handle_item(item3)
        counters.handle_item(item4)
        counters.get(['first'], @config1.find_dimension(:dim1)).should == {
          ['hello'] => {:met1s => 2, :met2s => 0},
          ['world'] => {:met1s => 0, :met2s => 1}
        }
      end
      
      it 'sums the total of each non-predicate metric given each segment of each dimension' do
        counters = Counters.new(@config2)
        item1 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :met1 => 1, :met2 => 3)
        item2 = stub(:master => 'first', :dim1 => 'world', :dim2 => 'bar', :met1 => 4, :met2 => 99)
        item3 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'bar', :met1 => 6, :met2 => 1)
        item4 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'baz', :met1 => 1, :met2 => 45)
        counters.handle_item(item1)
        counters.handle_item(item2)
        counters.handle_item(item3)
        counters.handle_item(item4)
        counters.get(['first'], @config2.find_dimension(:dim1)).should == {
          ['hello'] => {:met1 => 8, :met2 => 49},
          ['world'] => {:met1 => 4, :met2 => 99}
        }
      end
      
      it 'handles dimension combinations' do
        counters = Counters.new(@config3)
        item1 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)
        item2 = stub(:master => 'first', :dim1 => 'world', :dim2 => 'bar', :dim3 => 'plonk', :met1? => false, :met2? => true)
        item3 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'bar', :dim3 => 'plunk', :met1? => false, :met2? => false)
        item4 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)
        counters.handle_item(item1)
        counters.handle_item(item2)
        counters.handle_item(item3)
        counters.handle_item(item4)
        counters.get(['first'], @config3.find_dimension(:dim2, :dim3)).should == {
          ['foo', 'plink'] => {:met1s => 2, :met2s => 0},
          ['bar', 'plonk'] => {:met1s => 0, :met2s => 1},
          ['bar', 'plunk'] => {:met1s => 0, :met2s => 0}
        }
      end
    
      it 'delegates special metrics' do
        special = Object.new
        def special.default
          {:xor => 0}
        end
        def special.calculate(metrics, item)
          metrics[:xor] ||= 0
          metrics[:xor] += 1 if item.met1? ^ item.met2?
        end
        counters = Counters.new(@config4, :specials => [special])
        item1 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)
        item2 = stub(:master => 'first', :dim1 => 'world', :dim2 => 'bar', :dim3 => 'plonk', :met1? => false, :met2? => true)
        item3 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'bar', :dim3 => 'plunk', :met1? => false, :met2? => false)
        item4 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)          
        counters.handle_item(item1)
        counters.handle_item(item2)
        counters.handle_item(item3)
        counters.handle_item(item4)
        counters.get(['first'], @config4.find_dimension(:dim1)).should == {
          ['hello'] => {:met1s => 2, :met2s => 0, :xor => 2},
          ['world'] => {:met1s => 0, :met2s => 1, :xor => 1}
        }
      end
    end
  
    describe '#each' do
      it 'yields each key/dimension/segment combination' do
        counters = Counters.new(@config3)
        item1 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)
        item2 = stub(:master => 'first', :dim1 => 'world', :dim2 => 'bar', :dim3 => 'plonk', :met1? => false, :met2? => true)
        item3 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'bar', :dim3 => 'plunk', :met1? => false, :met2? => false)
        item4 = stub(:master => 'first', :dim1 => 'hello', :dim2 => 'foo', :dim3 => 'plink', :met1? => true,  :met2? => false)
        counters.handle_item(item1)
        counters.handle_item(item2)
        counters.handle_item(item3)
        counters.handle_item(item4)
        data = []
        counters.each { |d| data << d }
        data.should == [
          {:keys => {:master => 'first'}, :dimension => @config3.find_dimension(:dim1),        :segments => {:dim1 => 'hello'},                 :metrics => {:met1s => 2, :met2s => 0}},
          {:keys => {:master => 'first'}, :dimension => @config3.find_dimension(:dim1),        :segments => {:dim1 => 'world'},                 :metrics => {:met1s => 0, :met2s => 1}},
          {:keys => {:master => 'first'}, :dimension => @config3.find_dimension(:dim2, :dim3), :segments => {:dim2 => 'foo', :dim3 => 'plink'}, :metrics => {:met1s => 2, :met2s => 0}},
          {:keys => {:master => 'first'}, :dimension => @config3.find_dimension(:dim2, :dim3), :segments => {:dim2 => 'bar', :dim3 => 'plonk'}, :metrics => {:met1s => 0, :met2s => 1}},
          {:keys => {:master => 'first'}, :dimension => @config3.find_dimension(:dim2, :dim3), :segments => {:dim2 => 'bar', :dim3 => 'plunk'}, :metrics => {:met1s => 0, :met2s => 0}}
        ]
      end
    end
  end
end
