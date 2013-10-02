module Vidibus # :nodoc
  module Service # :nodoc
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ConnectorError < Error; end
  end
end
