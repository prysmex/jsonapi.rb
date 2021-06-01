lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rails_jsonapi/version'

Gem::Specification.new do |spec|
  spec.name          = 'rails_jsonapi'
  spec.version       = RailsJSONAPI::VERSION
  spec.authors       = ['Stas Suscov']
  spec.email         = ['stas@nerd.ro']

  spec.summary       = 'Rails integration for jsonapi-serializer and jsonapi-deserializable'
  spec.description   = (
    'Rails integration for jsonapi-serializer and jsonapi-deserializable'
  )
  spec.homepage      = 'https://github.com/prysmex/jsonapi.rb'
  spec.license       = 'MIT'

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(spec)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'jsonapi-deserializable', '0.2.0'
  spec.add_dependency 'jsonapi-serializer', '~> 2.2'
  spec.add_dependency 'rack'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rails', ENV['RAILS_VERSION']
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-rails'
  spec.add_development_dependency 'jsonapi-rspec'
  spec.add_development_dependency 'rubocop-rails_config'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
end
