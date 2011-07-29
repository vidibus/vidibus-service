# encoding: utf-8
lib = File.expand_path("../lib/", __FILE__)
$:.unshift lib unless $:.include?(lib)

require "vidibus/service/version"

Gem::Specification.new do |s|
  s.name        = "vidibus-service"
  s.version     = Vidibus::Service::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = "Andre Pankratz"
  s.email       = "andre@vidibus.com"
  s.homepage    = "https://github.com/vidibus/vidibus-service"
  s.summary     = "Service handling for Vidibus applications"
  s.description = "Enables Vidibus Services for the embedding Rails application"

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "vidibus-service"

  s.add_dependency "mongoid", "~> 2"
  s.add_dependency "vidibus-core_extensions"
  s.add_dependency "vidibus-secure"
  s.add_dependency "vidibus-uuid"
  s.add_dependency "vidibus-validate_uri"
  s.add_dependency "httparty"
  s.add_dependency "json"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "rake"
  s.add_development_dependency "rdoc"
  s.add_development_dependency "rcov"
  s.add_development_dependency "rspec", "~> 2"
  s.add_development_dependency "rr"
  s.add_development_dependency "webmock"
  s.add_development_dependency "rack-test"

  s.files = Dir.glob("{lib,app,config}/**/*") + %w[LICENSE README.md Rakefile]
  s.require_path = "lib"
end
