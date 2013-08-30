require "json"

module Vidibus
  module Service
    class ConnectorApp
      class SignatureError < StandardError; end
      class ValidationError < StandardError; end
      class SetupError < StandardError; end

      def self.call(env)
        self.new.call(env)
      end

      def call(env)
        @request = Rack::Request.new(env)
        unless @request.path == "/connector"
          return response(:error => "This app must be configured to respond to /connector path.")
        end
        method = @request.request_method.downcase
        if respond_to?(method)
          send(method)
        else
          response(:error => "Invalid request method: #{method}")
        end
      end

      protected

      # Creates this service and, unless it has already been set up, a Connector service.
      # Once this service has been created, a secret will be traded for the given nonce.
      def post
        if service.where(:this => true, :realm => nil).first
          raise SetupError, "This service has already been set up."
        end
        service.local(:connector) || create_connector!
        create_this!
        response({:success => "Setup successful"}, 201)
      rescue SetupError => e
        response(:error => e.message)
      end

      # Returns settings of this and Connector.
      # This action must only be called by Connector. Thus it is signed
      # with the service's secret.
      def get
        verify_request!
        out = {:this => this.public_data}
        if connector = service.local(:connector)
          out[:connector] = connector.public_data
        end
        response(out)
      rescue => e
        response(:error => e.message)
      end

      # Updates data of given services.
      def put
        verify_request!
        for uuid, attributes in @request.params.except("sign")
          unless Vidibus::Uuid.validate(uuid)
            raise "Updating failed: '#{uuid}' is not a valid UUID."
          end
          conditions = {:uuid => uuid}
          if realm_uuid = attributes.delete("realm_uuid")
            conditions[:realm_uuid] = realm_uuid
          end
          result = service.where(conditions)
          unless result.any?
            raise "Updating service #{uuid} failed: This service does not exist!"
          end
          for _service in result
            _service.attributes = attributes
            unless _service.save
              raise "Updating service #{uuid} failed: #{_service.errors.full_messages}"
            end
          end
        end
        response(:success => "Services updated.")
      rescue => e
        response(:error => e.message)
      end

      # Deletes services by their UUID.
      def delete
        verify_request!
        unless uuids = @request.params["uuids"]
          raise "Provide list of UUIDs of services to delete."
        end
        for uuid in uuids
          _service = service.where(:uuid => uuid).first
          next unless _service
          unless _service.destroy
            raise "Deleting service #{uuid} failed: #{_service.errors.full_messages.join(',')}"
          end
        end
        response(:success => "Services have been deleted.")
      rescue => e
        response(:error => e.message)
      end

      # Verifies that the signature is valid.
      def verify_request!
        unless Vidibus::Secure.verify_request(@request.request_method, @request.url, @request.params, this.secret)
          raise SignatureError.new("Invalid signature.")
        end
      end

      # Renders response.
      def response(data, status = nil, type = :js)
        if data[:error]
          status ||= 400
        else
          status ||= 200
        end
        Rack::Response.new([data.to_json], status, content_type(type)).finish
      end

      # Sets content type for response.
      def content_type(type = nil)
        string = case type
        when :js
          "text/javascript; charset=utf-8"
        else
          "text/html; charset=utf-8"
        end
        { 'Content-Type' => string }
      end

      # Returns service class.
      def service
        @service ||= ::Service
      end

      # Returns data of this service.
      # It will raise an error if this service is unconfigured.
      def this
        @this ||= service.this
      end

      # Returns data of the Connector.
      # It will raise an error if this service is unconfigured.
      def connector
        @connector ||= service.connector
      end

      # Creates Connector service from params containing +function+ "connector".
      def create_connector!
        uuid, data = @request.params.select {|k,v| v["function"] == "connector"}.first
        raise SetupError, "No Connector data given." unless data
        connector = service.new(data)
        unless connector.save
          raise SetupError, "Setting up the Connector failed: #{connector.errors.full_messages}"
        end
        connector
      end

      # Creates this service from params containing "this".
      def create_this!
        uuid, data = @request.params.select {|k,v| v["this"] == "true"}.first
        raise SetupError, "No data given for this service." unless data

        this = service.new(data)
        this.valid?
        unless this.errors.messages.except(:secret).empty?
          raise ValidationError
        end
        set_secret!(this)
        this.save or raise ValidationError
      rescue ValidationError
        raise SetupError, "Setting up this service failed: #{this.errors.full_messages}"
      end

      # Trades given nonce for secret.
      def set_secret!(service)
        raise SetupError, "Setting a secret for this service is not allowed!" if service.secret
        nonce = service.nonce
        raise SetupError, "No nonce given." unless nonce and nonce != ""

        fetched = fetch_secret(service)
        service.secret = decrypt_secret!(fetched["secret"], nonce, fetched["sign"])
      end

      # Requests encrypted secret for given service from Connector.
      def fetch_secret(service)
        uri = "#{connector.url}/services/#{service.uuid}/secret"
        HTTParty.get(uri, :format => :json)
      end

      # Decrypts secret with nonce.++
      def decrypt_secret!(secret, nonce, sign)
        unless Vidibus::Secure.sign(secret, nonce) == sign
          raise SetupError, "Nonce is invalid."
        end
        Vidibus::Secure.decrypt(secret, nonce)
      end
    end
  end
end
