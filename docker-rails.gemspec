# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'docker/rails/version'

Gem::Specification.new do |s|
  s.name          = 'docker-rails'
  s.version       = Docker::Rails::VERSION
  s.authors       = ['Kevin Ross']
  s.email         = ['kevin.ross@alienfast.com']
  s.summary       = %q{A simplified pattern to execute rails applications within Docker (with a CI build emphasis)}
  s.description   = %q{}
  s.homepage      = ''
  s.license       = 'MIT'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'rake'

  s.add_dependency 'docker-api'
  # s.add_dependency 'parallel_tests'
  s.add_dependency 'dry-config', '>= 1.1.6'
  s.add_dependency 'mysql2', '~> 0.3.18' # http://stackoverflow.com/a/32466950/2363935
end
