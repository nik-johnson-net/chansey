DESCRIPTION = <<eos
  A framework for building a service which interacts with multiple services
  using runtime loadable plugins.
eos

Gem::Specification.new do |s|
  s.name        = 'chansey'
  s.version     = '0.0.1'
  # TODO(njohnson) Update to BSD when ready
  # s.licenses    = []
  s.summary     = "A bot framework for interacting with other applications"
  s.description = DESCRIPTION
  s.authors     = ["Nik Johnson"]
  s.email       = 'jumpandspintowin@gmail.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['test/**/*.rb'] + Dir['bin/*']
  s.bindir      = 'bin'
  s.executables = 'chansey'
  s.homepage    = 'https://github.com/jumpandspintowin/chansey'

  s.add_runtime_dependency 'em-shorturl',  '~> 0.1'
  s.add_runtime_dependency 'eventmachine', '~> 1.0'
  s.add_runtime_dependency 'trollop',      '~> 2.0'
  s.add_runtime_dependency 'tweetstream',  '~> 2.5'
end
