require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
end

$:.unshift File.expand_path('../../', __FILE__)

require "rubygems"
require "active_support/core_ext"
require "rspec"
require "rr"
require "mongoid"
require "rack/test"
require "webmock/rspec"
require "ostruct"

require "vidibus-service"
require "app/models/service"

Mongoid.configure do |config|
  name = "vidibus-service_test"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
  config.logger = nil
end

RSpec.configure do |config|
  config.include WebMock::API
  config.mock_with :rr
  config.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/}.each(&:drop)
  end
end

I18n.load_path += Dir[File.join('config', 'locales', '**', '*.{rb,yml}')]

#ENV["VIDIBUS_SECURE_KEY"] = "c4l60HC/lyerr2VEnrP7s2YAldyZGfIBePUzCl+tBsTs1EWJOc8dEJ7F2Vty7KPEeRuBWGxZHVAbku8pLo+UvXRpLcRiF7lxKiKl"
