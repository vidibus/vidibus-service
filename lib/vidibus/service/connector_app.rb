require "json"

module Vidibus
  module Service
    class ConnectorApp
      class SignatureError < StandardError; end

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
      # Once this service has been created, a secret will be traded for given nonce.
      def post
        unless this = service.where(:this => true, :realm => nil).first
          unless connector = service.local(:connector)
            connector_data = @request.params["connector"] or
              return response(:error => "No Connector data given.")
            connector = service.new(connector_data.merge(:function => "connector"))
            unless connector.save
              return response(:error => "Setting up the Connector failed: #{connector.errors.full_messages}")
            end
          end
          this_data = @request.params["this"] or
            return response(:error => "No data for this service given.")
          this = service.new(this_data.merge(:this => true))
          this.secret = "this is just a mock"
          if this.valid?
            nonce = @request.params["this"]["nonce"]
            unless nonce == ""
              uri = "#{connector.url}/services/#{this.uuid}/secret"
              res = HTTParty.get(uri, :format => :json)
            end
            unless nonce.to_s.length > 5 and Vidibus::Secure.sign(res["secret"], nonce) == res["sign"]
              return response(:error => "Nonce is invalid.")
            end
            this.secret = Vidibus::Secure.decrypt(res["secret"], nonce)
            if this.save
              return response({:success => "Setup successful"}, 201)
            end
          end
          response(:error => "Setting up this service failed: #{this.errors.full_messages}")
        else
          response(:error => "Service has already been set up.")
        end
      end

      # Returns settings of this and Connector.
      # This action must only be called by Connector. Thus it is signed
      # with the Service's secret.
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
      # If a service does not exist, it will be created.
      def put
        verify_request!
        for function, attributes in @request.params.except("sign")
          _service = service.local(function) || service.new(:function => function)
          _service.attributes = attributes
          unless _service.save
            return response(:error => "Updating #{function} failed: #{_service.errors.full_messages}")
          end
        end
        response(:success => "Services updated.")
      rescue => e
        response(:error => e.message)
      end

      # Deletes services by their UUID.
      def delete
        verify_request!
        raise ArgumentError.new("Provide list of :uuids") unless uuids = @request.params["uuids"]
        for uuid in uuids
          if found = service.where(:uuid => uuid).first
            found.destroy
          end
        end
        response(:success => "Services have been deleted.")
      rescue => e
        response(:error => e.message)
      end

      # Verifies that signature is valid.
      def verify_request!
        Vidibus::Secure.verify_request(@request.request_method, @request.url, @request.params, this.secret) or
          raise SignatureError.new("Invalid signature.")
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
    end
  end
end
