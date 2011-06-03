# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  describe ConfigurationDsl do
    context 'creating a simple counting configuration' do
      subject do
        ConfigurationDsl.counters do
          main_keys :main_key_1, :main_key_2, :main_key_3

          # single property dimensions
          dimension :dimension_1
          dimension :dimension_2
          
          # multi property dimension
          dimension :dimension_1, :dimension_2
          
          # dimension with metadata and extra metrics
          dimension :dimension_3 do
            meta :meta_1, :meta_2
            metric :metric_3s, :message => :metric_3?
          end

          # metric with explicit :message and :type options
          metric :metric_1s, :message => :metric_1?, :type => :predicate
          # metric with implicit :message
          metric :metric_2s, :metric_2
          # metric with message name == metric name
          metric :metric_x
        end
      end
    
      it 'has the right main keys' do
        subject.main_keys.should == [:main_key_1, :main_key_2, :main_key_3]
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
          :metric_1s => Metric.new(:metric_1s, :metric_1?, :predicate), 
          :metric_2s => Metric.new(:metric_2s, :metric_2),
          :metric_x => Metric.new(:metric_x, :metric_x)
        }
      end
      
      it 'captures the additional metrics for a dimension' do
        dimension = subject.find_dimension(:dimension_3)
        dimension.metrics.should == {
          :metric_1s => Metric.new(:metric_1s, :metric_1?, :predicate), 
          :metric_2s => Metric.new(:metric_2s, :metric_2),
          :metric_3s => Metric.new(:metric_3s, :metric_3?),
          :metric_x => Metric.new(:metric_x, :metric_x)
        }
      end
    end
  end
end
