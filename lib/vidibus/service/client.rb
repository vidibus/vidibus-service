require "httparty"

module Vidibus
  module Service
    class Client
      include HTTParty
      format :json

      class ServiceError < Error; end
      class RequestError < Error; end

      attr_accessor :base_uri, :service, :this

      # Initializes a new client for given service.
      def initialize(service)
        unless service && service.is_a?(::Service)
          raise(ServiceError, 'Service required')
        end
        unless service.url
          raise(ServiceError, 'URL of service required')
        end
        self.service = service
        self.this = ::Service.this
        self.base_uri = service.url
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

      protected

      # Extends given query options and sends request with given verb.
      def request(verb, path, options)
        options_type = %w[post put].include?(verb.to_s) ? :body : :query
        options[options_type] = {:realm => service.realm_uuid, :service => this.uuid}.merge(options[options_type] || {})
        uri = build_uri(path)
        Vidibus::Secure.sign_request(verb, uri, options[options_type], secret)
        begin
          self.class.send(verb, uri, options)
        rescue StandardError, Exception => e
          raise(RequestError, e.message, e.backtrace)
        end
      end

      # Builds URI from base URI of service and given path.
      def build_uri(path)
        path = path.to_s
        unless path.match(/^\//)
          path = "/#{path}"
        end
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
