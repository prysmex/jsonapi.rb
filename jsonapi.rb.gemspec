# frozen_string_literal: true

require_relative 'lib/rails_jsonapi/version'

Gem::Specification.new do |spec|
  spec.name          = 'rails_jsonapi'
  spec.version       = RailsJSONAPI::VERSION
  spec.authors       = ['Stas Suscov']
  spec.email         = ['stas@nerd.ro']

  spec.summary       = 'Rails jsonapi by integrating jsonapi-serializer and jsonapi-deserializable'
  spec.description   = (
    'Rails jsonapi by integrating jsonapi-serializer and jsonapi-deserializable'
  )
  spec.homepage      = 'https://github.com/prysmex/jsonapi.rb'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4.2'

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'jsonapi-deserializable', '~> 0'
  spec.add_dependency 'jsonapi-serializer', '~> 2.2'
  spec.add_dependency 'oj', '~> 3'
  spec.add_dependency 'rack'
end
