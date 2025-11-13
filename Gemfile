# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in json_schema_form.gemspec
gemspec

gem 'jsonapi-deserializable', '~> 0', git: 'https://github.com/prysmex/jsonapi-deserializable.git'
gem 'jsonapi-rspec', git: 'https://github.com/jsonapi-rb/jsonapi-rspec.git'
gem 'jsonapi-serializer', '~> 2.2'

# gem 'bundler', '2.6.2'
gem 'debug', '>= 1.10'
# gem 'minitest', '~> 5.25'
# gem 'minitest-reporters', '~> 1.7'
gem 'rails', ENV.fetch('RAILS_VERSION', nil)
gem 'rake', '~> 13.3'

# rubocop
gem 'rubocop', '~> 1.81'
# gem 'rubocop-minitest', '~> 0.38'
gem 'rubocop-performance', '~> 1.26'
gem 'rubocop-rake', '~> 0.7'