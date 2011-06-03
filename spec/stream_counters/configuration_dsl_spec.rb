# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  describe ConfigurationDsl do
    include ConfigurationDsl
    
    context 'basic configuration' do
      subject do
        configuration do
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
        config = ConfigurationDsl.configuration do
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
  
    context 'merging' do
      subject do
        configuration do
          main_keys :key1
          dimension :dim1
          dimension :dim2
          metric :metric1
          metric :metric2
        end.merge do
          # overrides old main keys
          main_keys :key2
          # overrides old dimension
          dimension :dim2 do
            meta :test
          end
          # adds a new dimension
          dimension :dim3
          # overrides a metric
          metric :metric1, :type => :special
          # adds a metric to all dimensions, old and new
          metric :metric3
        end
      end
      
      it 'overrides main_keys' do
        subject.main_keys.should == [:key2]
      end
      
      it 'contains the union of the dimensions' do
        subject.find_dimension(:dim1).should_not be_nil
        subject.find_dimension(:dim2).should_not be_nil
        subject.find_dimension(:dim3).should_not be_nil
      end
      
      it 'overrides dimensions with the same name' do
        subject.find_dimension(:dim2).meta.should == [:test]
      end
      
      it 'adds new metrics to all dimensions' do
        subject.find_dimension(:dim1).metrics.should == {
          :metric1 => Metric.new(:metric1, :metric1, :special),
          :metric2 => Metric.new(:metric2),
          :metric3 => Metric.new(:metric3)
        }
        subject.find_dimension(:dim3).metrics.should == {
          :metric1 => Metric.new(:metric1, :metric1, :special),
          :metric2 => Metric.new(:metric2),
          :metric3 => Metric.new(:metric3)
        }
      end
    end
  end
end
