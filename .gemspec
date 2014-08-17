require_relative 'lib/chansey/version'

Gem::Specification.new do |s|
  DESCRIPTION = <<eos
  A framework for building a service which interacts with multiple services.
eos

  s.name        = 'chansey'
  s.version     = Chansey::VERSION
  s.licenses    = ['BSD-3-Clause']
  s.summary     = 'A bot framework for interacting with other applications'
  s.description = DESCRIPTION
  s.authors     = ['Nik Johnson']
  s.email       = 'jumpandspintowin@gmail.com'
  s.files       = Dir['lib/chansey/*.rb'] + Dir['lib/chansey.rb']
  s.homepage    = 'https://github.com/jumpandspintowin/chansey'

  s.add_runtime_dependency 'eventmachine', '~> 1.0'
end
