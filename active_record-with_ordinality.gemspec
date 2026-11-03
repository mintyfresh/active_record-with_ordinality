# frozen_string_literal: true

require_relative 'lib/active_record/with_ordinality/version'

Gem::Specification.new do |spec|
  spec.name        = 'active_record-with_ordinality'
  spec.version     = ActiveRecord::WithOrdinality::VERSION
  spec.authors     = ['Minty Fresh']
  spec.email       = ['7896757+mintyfresh@users.noreply.github.com']
  spec.homepage    = 'https://github.com/mintyfresh/active_record-with_ordinality'
  spec.summary     = 'Ordinal joins for ActiveRecord relations'
  spec.description = 'Joins lists of values to ActiveRecord relations with their ordinal positions, ' \
                     'and orders relations by them with in_order_of.'
  spec.license     = 'MIT'

  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['lib/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'activerecord', '>= 8.1'
end
