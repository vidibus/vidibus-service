require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$:.unshift File.expand_path('../../', __FILE__)

require 'rubygems'
require 'active_support'
require 'active_support/core_ext'
require 'rspec'
require 'rr'
require 'mongoid'
require 'rack/test'
require 'webmock/rspec'
require 'ostruct'
require 'database_cleaner'

require 'vidibus-service'
require 'app/models/service'

Mongo::Logger.logger.level = Logger::FATAL

Mongoid.configure do |config|
  config.connect_to('vidibus-service_test')
end

RSpec.configure do |config|
  config.include WebMock::API
  config.mock_with :rr
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]

#ENV['VIDIBUS_SECURE_KEY'] = 'c4l60HC/lyerr2VEnrP7s2YAldyZGfIBePUzCl+tBsTs1EWJOc8dEJ7F2Vty7KPEeRuBWGxZHVAbku8pLo+UvXRpLcRiF7lxKiKl'
