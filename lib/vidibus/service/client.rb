require "httparty"

module Vidibus
  module Service
    class Client
      include HTTParty
      format :json

      class ServiceError < Error; end

      attr_accessor :base_uri, :service, :this

      # Initializes a new client for given service.
      def initialize(service)
        raise ServiceError.new("Service required") unless service and service.is_a?(::Service)
        self.service = service
        self.this = ::Service.this
        self.base_uri = service.url or raise(ServiceError.new("URL of service required"))
      end

      # Sends a GET request to given path.
      def get(path, options = {})
        request(:get, path, options)
      end

      # Sends a POST request to given path.
      def post(path, options = {})
        request(:post, path, options)
      end

      # Sends a PUT request to given path.
      def put(path, options = {})
        request(:put, path, options)
      end

      # Sends a DELETE request to given path.
      def delete(path, options = {})
        request(:delete, path, options)
      end
      
      def response
        super
      end

      protected

      # Extends given query options and sends request with given verb.
      def request(verb, path, options)
        options[:query] = {:realm => service.realm_uuid, :service => this.uuid}.merge(options[:query] || {})
        uri = build_uri(path)
        Vidibus::Secure.sign_request(verb, uri, options[:query], secret)
        self.class.send(verb, uri, options)
      end

      # Builds URI from base URI of service and given path.
      def build_uri(path)
        path = path.to_s
        raise("Expected path, got #{path}") unless path.match(/^\//)
        base_uri + path
      end

      # Returns secret to use depending on given service. If a Connector is about to be contacted,
      # the secret of this service will be used, otherwise the secret of the contacted service.
      def secret
        (@service.connector? and @service.secret == nil) ? @this.secret : @service.secret
      end
    end
  end
end