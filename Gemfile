# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in json_schema_form.gemspec
gemspec

gem 'jsonapi-deserializable', '~> 0', git: 'https://github.com/prysmex/jsonapi-deserializable.git'
gem 'jsonapi-rspec', git: 'https://github.com/jsonapi-rb/jsonapi-rspec.git'
gem 'jsonapi-serializer', '~> 2.2'

# gem 'bundler', '2.4.22'
gem 'debug', '>= 1.9'
# gem 'minitest', '~> 5.25'
# gem 'minitest-reporters', '~> 1.7'
gem 'rails', ENV.fetch('RAILS_VERSION', nil)
gem 'rake', '~> 13.2'

# rubocop
gem 'rubocop', '~> 1.68'
# gem 'rubocop-minitest', '~> 0.36'
gem 'rubocop-performance', '~> 1.23'
gem 'rubocop-rake', '~> 0.6'