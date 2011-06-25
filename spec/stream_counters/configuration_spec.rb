# encoding: utf-8

require_relative '../spec_helper'


module StreamCounters
  class TestClass1
  end
  
  class TestClass2
    attr_reader :xyz, :some_count
  end
  
  class TestClass3
    attr_reader :xyz, :abc, :def, :some_count, :another_number
  end
  
  describe Configuration do
    include ConfigurationDsl

    before do
      @config = configuration do
        base_keys :xyz
        dimension :abc
        dimension :def
        metric :some_sum, :some_count
        metric :another_sum, :another_number
      end
    end
    
    describe '#validate_class' do
      it 'returns an array of the methods that are missing (1)' do
        methods = @config.validate_class(TestClass1)
        methods.should == [:xyz, :abc, :def, :some_count, :another_number].sort
      end
      
      it 'returns an array of the methods that are missing (2)' do
        methods = @config.validate_class(TestClass2)
        methods.should == [:abc, :def, :another_number].sort
      end

      it 'returns an empty array when no methods are missing' do
        methods = @config.validate_class(TestClass3)
        methods.should be_empty
      end
    end
    
    describe '#validate_class!' do
      it 'raises an error when there are methods missing' do
        expect { @config.validate_class!(TestClass2) }.to raise_error(TypeError)
      end
      
      it 'does not raise an error when no methods are missing' do
        expect { @config.validate_class!(TestClass3) }.to_not raise_error(TypeError)
      end
    end
  end
end
