# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rsolr/cloud/version'

Gem::Specification.new do |spec|
  spec.name          = 'rsolr-cloud'
  spec.version       = Rsolr::Cloud::VERSION
  spec.authors       = ['Shintaro Kimura']
  spec.email         = ['service@enigmo.co.jp']
  spec.summary       = 'The connection adopter supporting SolrCloud for RSolr'
  spec.description   = 'The connection adopter supporting SolrCloud for RSolr'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.3'
  spec.add_development_dependency 'activesupport', '~> 4.2'
  spec.add_development_dependency 'zk-server', '~> 1.1.7'
  spec.add_development_dependency 'zk', '~> 1.9.5'
  spec.add_development_dependency 'rsolr', '~> 1.0.12'
  spec.add_development_dependency 'rubocop', '~> 0.49.0'
end
