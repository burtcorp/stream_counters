# encoding: utf-8

$: << File.expand_path('../lib', __FILE__)

require 'stream_counters/version'


Gem::Specification.new do |s|
  s.name        = 'stream_counters'
  s.version     = StreamCounters::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Theo Hultberg']
  s.email       = ['theo@burtcorp.com']
  s.homepage    = 'http://github.com/burtcorp/stream_counters'
  s.summary     = %q{}
  s.description = %q{}

  s.rubyforge_project = 'stream_counters'
  
  s.add_development_dependency 'rspec'

  s.files         = `git ls-files`.split("\n")
  # s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  # s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = %w(lib)
end
