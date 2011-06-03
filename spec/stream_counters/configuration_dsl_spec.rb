# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  describe ConfigurationDsl do
    context 'creating a simple counting configuration' do
      subject do
        ConfigurationDsl.counters do
          main_keys :main_key_1, :main_key_2, :main_key_3
          sort_keys :main_key_2
          dimension :dimension_1
          dimension :dimension_2
          dimension :dimension_3 do
            meta :meta_1, :meta_2
            metric :metric_3s, :metric_3?
          end
          dimension :dimension_1, :dimension_2
          metric :metric_1s, :metric_1?
          metric :metric_2s, :metric_2
        end
      end
    
      it 'has the right main keys' do
        subject.main_keys.should == [:main_key_1, :main_key_2, :main_key_3]
      end
      
      it 'has the right sort key' do
        subject.sort_keys.should == [:main_key_2]
      end
      
      it 'captures dimensions (without meta)' do
        subject.find_dimension(:dimension_1).should_not be_nil
        subject.find_dimension(:dimension_2).should_not be_nil
        subject.find_dimension(:dimension_1, :dimension_2).should_not be_nil
      end
      
      it 'sorts the dimension property names in alphabetical order' do
        config = ConfigurationDsl.counters do
          main_keys :x
          dimension :b, :a
        end
        config.dimensions.first.keys.should == [:a, :b]
      end
      
      it 'captures dimensions (with meta)' do
        dimension = subject.find_dimension(:dimension_3)
        dimension.meta.should == [:meta_1, :meta_2]
      end
      
      it 'captures the default metrics' do
        dimension = subject.find_dimension(:dimension_1)
        dimension.metrics.should == {
          :metric_1s => Metric.new(:metric_1s, :metric_1?), 
          :metric_2s => Metric.new(:metric_2s, :metric_2)
        }
      end
      
      it 'captures the additional metrics for a dimension' do
        dimension = subject.find_dimension(:dimension_3)
        dimension.metrics.should == {
          :metric_1s => Metric.new(:metric_1s, :metric_1?), 
          :metric_2s => Metric.new(:metric_2s, :metric_2),
          :metric_3s => Metric.new(:metric_3s, :metric_3?)
        }
      end
    end
  end
end
