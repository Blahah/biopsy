# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require File.expand_path('../lib/biopsy/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name          = 'biopsy'
  gem.authors       = [ "Richard Smith" ]
  gem.email         = "rds45@cam.ac.uk"
  gem.homepage      = 'https://github.com/Blahah/biopsy'
  gem.summary       = %q{ framework for optimising any computational pipeline or program }
  gem.version       = Biopsy::VERSION::STRING.dup

  gem.files = Dir['Rakefile', '{lib,test}/**/*', 'README*', 'LICENSE*']
  gem.require_paths = %w[ lib ]

  gem.add_dependency 'rake', '~> 10.3'
  gem.add_dependency 'threach'
  gem.add_dependency 'rubystats'
  gem.add_dependency 'statsample'

  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'turn', '~> 0.9'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'shoulda-context'
  gem.add_development_dependency 'coveralls', '~> 0.6.7'
end