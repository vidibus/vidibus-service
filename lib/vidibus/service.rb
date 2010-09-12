module Vidibus # :nodoc
  module Service # :nodoc
    class Error < StandardError; end
  end
end

require "service/client"
require "service/mongoid"
require "service/connector_app"

# Shorthand for Service.discover
def Service(wanted, realm)
  Service.discover(wanted, realm)
end
