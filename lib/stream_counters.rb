# encoding: utf-8


module StreamCounters
  autoload :Counters, 'stream_counters/counters'
  autoload :Configuration, 'stream_counters/configuration'
  autoload :ConfigurationDsl, 'stream_counters/configuration_dsl'
  autoload :Dimension, 'stream_counters/types'
  autoload :Keys, 'stream_counters/types'
  autoload :Metric, 'stream_counters/types'
end
