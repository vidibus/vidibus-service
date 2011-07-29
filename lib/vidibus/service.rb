require "vidibus/service/errors"
require "vidibus/service/client"
require "vidibus/service/mongoid"
require "vidibus/service/connector_app"
require "vidibus/service/controller_validations"

# Shorthand for Service.discover
def Service(wanted, realm)
  Service.discover(wanted, realm)
end
