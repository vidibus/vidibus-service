require "vidibus-secure"
require "vidibus-validate_uri"
require "vidibus-uuid"
require "vidibus-core_extensions"

require "vidibus/service"

if defined?(Rails)
  module Vidibus::Service
    class Engine < ::Rails::Engine; end
  end
end
