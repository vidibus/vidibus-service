# require "rails"
require "vidibus-secure"
require "vidibus-validate_uri"
require "vidibus-uuid"
require "vidibus-core_extensions"

$:.unshift(File.join(File.dirname(__FILE__), "vidibus"))
require "service"

if defined?(Rails)
  module Vidibus::Service
    class Engine < ::Rails::Engine; end
  end
end
