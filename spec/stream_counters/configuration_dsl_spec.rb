# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  describe ConfigurationDsl do
    include ConfigurationDsl
    
    context 'basic configuration' do
      subject do
        configuration do
          base_keys :main_key_1, :main_key_2, :main_key_3

          # single property dimensions
          dimension :dimension_1
          dimension :dimension_2
          
          # multi property dimension
          dimension :dimension_1, :dimension_2
          
          # dimension with metadata and extra metrics
          dimension :dimension_3 do
            meta :meta_1, :meta_2
            metric :metric_3s, :message => :metric_3?
            discard_nil_segments true
          end

          # boxed dimension
          dimension :boxed_dimension do
            metric :metric_3s, :message => :metric_3?
            boxed_segment :boxed_dimension, :boxing_metric, [1, 5, 10, 20]
          end

          # combined, boxed dimension
          dimension :dimension_1, :boxed_dimension do
            metric :metric_3s, :message => :metric_3?
            boxed_segment :boxed_dimension, :boxing_metric, [1, 5, 10, 20]
          end

          # metric with explicit :message and :type options
          metric :metric_1s, :message => :metric_1?, :type => :predicate
          # metric with implicit :message
          metric :metric_2s, :metric_2
          # metric with message name == metric name
          metric :metric_x
          # metric with non-numeric type
          metric :non_numeric, :type => :list, :default => []
          # metric with conditional
          metric :conditional_metric, :if => :metric_1?
          # metric with conditional and context
          metric :conditional_metric_with_context, :if_with_context => :metric_1?
        end
      end
    
      it 'has the right base keys' do
        subject.base_keys.should == ['main_key_1', 'main_key_2', 'main_key_3']
      end

      it 'captures dimensions (without meta)' do
        subject.find_dimension('dimension_1').should_not be_nil
        subject.find_dimension('dimension_2').should_not be_nil
        subject.find_dimension('dimension_1', 'dimension_2').should_not be_nil
      end
      
      it 'keeps the dimension property names in the specified order' do
        config = ConfigurationDsl.configuration do
          base_keys :x
          dimension :b, :a
        end
        config.dimensions.first.keys.should == ['b', 'a']
      end
      
      it 'allows for dimensions with same keys in different orders' do
        config = ConfigurationDsl.configuration do
          base_keys :x
          dimension :b, :a do
            meta :x
          end
          dimension :a, :b do
            meta :y
          end
        end
        config.dimensions.length.should == 2
        config.dimensions.first.keys.should == ['b', 'a']
        config.dimensions.first.meta.should == ['x']
        config.dimensions.last.keys.should == ['a', 'b']
        config.dimensions.last.meta.should == ['y']
      end

      it 'captures dimensions (with meta)' do
        dimension = subject.find_dimension('dimension_3')
        dimension.meta.should == ['meta_1', 'meta_2']
        dimension.discard_nil_segments.should == true
      end
      
      it 'captures the default metrics' do
        dimension = subject.find_dimension('dimension_1')
        dimension.metrics.should == {
          'metric_1s' => Metric.new(:metric_1s, :metric_1?, :predicate), 
          'metric_2s' => Metric.new(:metric_2s, :metric_2),
          'metric_x' => Metric.new(:metric_x, :metric_x),
          'non_numeric' => Metric.new(:non_numeric, :non_numeric, :list, []),
          'conditional_metric' => Metric.new(:conditional_metric, :conditional_metric, Metric::DEFAULT_TYPE, Metric::DEFAULT_VALUE, :metric_1?),
          'conditional_metric_with_context' => Metric.new(:conditional_metric_with_context, :conditional_metric_with_context, Metric::DEFAULT_TYPE, Metric::DEFAULT_VALUE, Metric::DEFAULT_IF_MESSAGE, :metric_1?)
        }
      end
      
      it 'captures the additional metrics for a dimension' do
        dimension = subject.find_dimension('dimension_3')
        dimension.metrics.should == {
          'metric_1s' => Metric.new(:metric_1s, :metric_1?, :predicate), 
          'metric_2s' => Metric.new(:metric_2s, :metric_2),
          'metric_3s' => Metric.new(:metric_3s, :metric_3?),
          'metric_x' => Metric.new(:metric_x, :metric_x),
          'non_numeric' => Metric.new(:non_numeric, :non_numeric, :list, []),
          'conditional_metric' => Metric.new(:conditional_metric, :conditional_metric, Metric::DEFAULT_TYPE, Metric::DEFAULT_VALUE, :metric_1?),
          'conditional_metric_with_context' => Metric.new(:conditional_metric_with_context, :conditional_metric_with_context, Metric::DEFAULT_TYPE, Metric::DEFAULT_VALUE, Metric::DEFAULT_IF_MESSAGE, :metric_1?)
        }
      end
      
      it 'has base keys assigned to the dimension' do
        dimension = subject.find_dimension('dimension_1')
        dimension.base_keys.should == ['main_key_1', 'main_key_2', 'main_key_3']
      end

      it 'handles settings for boxed segments' do
        dimension = subject.find_dimension('boxed_dimension')
        dimension.boxed_segments.should == {
          'boxed_dimension' => BoxedSegment.new(:boxed_dimension, :boxing_metric, [1, 5, 10, 20])
        }
      end

      it 'handles settings for combination of non-boxed and boxed segments' do
        dimension = subject.find_dimension('dimension_1', 'boxed_dimension')
        dimension.boxed_segments.should == {
          'boxed_dimension' => BoxedSegment.new(:boxed_dimension, :boxing_metric, [1, 5, 10, 20])
        }
        dimension.keys.should == ['dimension_1', 'boxed_dimension']
      end
    end

    context 'serialization' do
      subject do
        configuration do
          base_keys :main_key_1, :main_key_2, :main_key_3

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

          # boxed dimension
          dimension :boxed_dimension do
            metric :metric_3s, :message => :metric_3?
            boxed_segment :boxed_dimension, :boxing_metric, [1, 5, 10, 20]
          end

          # metric with explicit :message and :type options
          metric :metric_1s, :message => :metric_1?, :type => :predicate
          # metric with implicit :message
          metric :metric_2s, :metric_2
          # metric with message name == metric name
          metric :metric_x
          # metric with non-numeric type
          metric :non_numeric, :type => :list, :default => []
          # metric with conditional
          metric :conditional_metric, :if => :metric_1?
        end
      end

      it 'serializes to a hash' do
        config = subject.to_h
        dimensions = config['dimensions']
        metrics = {
          'metric_1s' => {'name' => 'metric_1s', 'message' => 'metric_1?', 'type' => 'predicate', 'default' => 0, 'if_message' => nil},
          'metric_2s' => {'name' => 'metric_2s', 'message' => 'metric_2', 'type' => 'numeric', 'default' => 0, 'if_message' => nil},
          'metric_x' => {'name' => 'metric_x', 'message' => 'metric_x', 'type' => 'numeric', 'default' => 0, 'if_message' => nil},
          'non_numeric' => {'name' => 'non_numeric', 'message' => 'non_numeric', 'type' => 'list', 'default' => [], 'if_message' => nil},
          'conditional_metric' => {'name' => 'conditional_metric', 'message' => 'conditional_metric', 'type' => 'numeric', 'default' => 0, 'if_message' => 'metric_1?'}
        }
        config['metrics'].should == metrics
        config['base_keys'].should == ['main_key_1', 'main_key_2', 'main_key_3']
        dimensions["dimension_1"].should == {
          'keys' => ['dimension_1'],
          'base_keys' => ['main_key_1', 'main_key_2', 'main_key_3'],
          'metrics' => metrics
        }
        dimensions["dimension_2"].should == {
          'keys' => ['dimension_2'],
          'base_keys' => ['main_key_1', 'main_key_2', 'main_key_3'],
          'metrics' => metrics
        }
        dimensions["dimension_1 dimension_2"].should == {
          'keys' => ['dimension_1', 'dimension_2'],
          'base_keys' => ['main_key_1', 'main_key_2', 'main_key_3'],
          'metrics' => metrics
        }
        dimensions["dimension_3"].should == {
          'keys' => ['dimension_3'],
          'base_keys' => ['main_key_1', 'main_key_2', 'main_key_3'],
          'metrics' => metrics.merge('metric_3s' => {'name' => 'metric_3s', 'message' => 'metric_3?', 'type' => 'numeric', 'default' => 0, 'if_message' => nil}),
          'meta' => ['meta_1', 'meta_2']
        }
        
        dimensions["boxed_dimension"].should == {
          'keys' => ['boxed_dimension'],
          'base_keys' => ['main_key_1', 'main_key_2', 'main_key_3'],
          'metrics' => metrics.merge('metric_3s' => {'name' => 'metric_3s', 'message' => 'metric_3?', 'type' => 'numeric', 'default' => 0, 'if_message' => nil}),
          'boxed_segments' => [{'name' => 'boxed_dimension', 'metric' => 'boxing_metric', 'boxes' => [1, 5, 10, 20]}]
        }
      end
      
      it 'deserializes to the same config' do
        hash = {'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}}, 'dimensions'=>{"dimension_1"=>{'keys'=>['dimension_1'], 'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}}}, "dimension_2"=>{'keys'=>['dimension_2'], 'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}}}, "dimension_1 dimension_2"=>{'keys'=>['dimension_1', 'dimension_2'], 'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}}}, "dimension_3"=>{'keys'=>['dimension_3'], 'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}, 'metric_3s'=>{'name'=>'metric_3s', 'message'=>'metric_3?', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}}, 'meta'=>['meta_1', 'meta_2']}, "boxed_dimension"=>{'keys'=>['boxed_dimension'], 'base_keys'=>['main_key_1', 'main_key_2', 'main_key_3'], 'metrics'=>{'metric_1s'=>{'name'=>'metric_1s', 'message'=>'metric_1?', 'type'=>'predicate', 'default'=>0, 'if_message'=>nil}, 'metric_2s'=>{'name'=>'metric_2s', 'message'=>'metric_2', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'metric_x'=>{'name'=>'metric_x', 'message'=>'metric_x', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}, 'non_numeric'=>{'name'=>'non_numeric', 'message'=>'non_numeric', 'type'=>'list', 'default'=>[], 'if_message'=>nil}, 'conditional_metric'=>{'name'=>'conditional_metric', 'message'=>'conditional_metric', 'type'=>'numeric', 'default'=>0, 'if_message'=>'metric_1?'}, 'metric_3s'=>{'name'=>'metric_3s', 'message'=>'metric_3?', 'type'=>'numeric', 'default'=>0, 'if_message'=>nil}}, 'boxed_segments' => [{'name' => 'boxed_dimension', 'metric' => 'boxing_metric', 'boxes' => [1, 5, 10, 20]}]}}}


        config = Configuration.new(hash)
        config.dimensions.each do |dim|
          subject.find_dimension(*dim.keys).should == dim
        end
        config.base_keys.should == subject.base_keys
        config.metrics.should == subject.metrics
        config.find_dimension('boxed_dimension').boxed_segments.should == subject.find_dimension('boxed_dimension').boxed_segments
      end
    end

    context 'extension' do
      module ConfigDslExtension
        def stuff(*values)
          if values.empty?
            @stuff
          else
            @stuff = values
          end
        end
      end

      module ConfigExtension
        def stuff
          @stuff ||= @context.stuff
        end

        def to_h
          {
            'stuff' => stuff
          }
        end

        def deserialize(hash)
          @stuff = hash['stuff']
        end
      end

      class StreamCounters::ConfigurationDsl::DslSupport::ConfigurationContext
        include ConfigDslExtension
      end

      class StreamCounters::Configuration
        include ConfigExtension
      end

      subject do
        configuration do
          base_keys :key1
          dimension :dim1
          metric :metric1
          stuff 1, 2, 3
        end
      end

      it 'sends dsl context to Configuration on creation allowing extensions' do
        subject.stuff.should == [1, 2, 3]
      end

      it 'allows extension of to_h' do
        subject.to_h['stuff'].should == [1, 2, 3]
      end

      it 'allows extension of deserialize' do
        config = Configuration.new(subject.to_h)
        config.stuff.should == [1, 2, 3]
      end
    end
  
    context 'merging' do
      subject do
        configuration do
          base_keys :key1
          dimension :dim1
          dimension :dim2
          metric :metric1
          metric :metric2
        end.merge do
          # overrides old main keys
          base_keys :key2
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
      
      it 'overrides base_keys' do
        subject.base_keys.should == ['key2']
      end
      
      it 'contains the union of the dimensions' do
        subject.find_dimension('dim1').should_not be_nil
        subject.find_dimension('dim2').should_not be_nil
        subject.find_dimension('dim3').should_not be_nil
      end
      
      it 'overrides dimensions with the same name' do
        subject.find_dimension('dim2').meta.should == ['test']
      end
      
      it 'adds new metrics to all dimensions' do
        subject.find_dimension('dim1').metrics.should == {
          'metric1' => Metric.new(:metric1, :metric1, :special),
          'metric2' => Metric.new(:metric2),
          'metric3' => Metric.new(:metric3)
        }
        subject.find_dimension('dim3').metrics.should == {
          'metric1' => Metric.new(:metric1, :metric1, :special),
          'metric2' => Metric.new(:metric2),
          'metric3' => Metric.new(:metric3)
        }
      end
    end
  end
end
