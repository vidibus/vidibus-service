require "spec_helper.rb"

describe "Vidibus::Service::ConnectorApp" do
  include Rack::Test::Methods

  let(:this_params) { {"uuid" => "344b4b8088fb012dd3e558b035f038ab", "url" => "http://manager.local", "function" => "manager"} }
  let(:connector_params) { {"uuid" => "60dfef509a8e012d599558b035f038ab", "url" => "https://connector.local"} }
  let(:this) { Service.create!(this_params.merge(:secret => "EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr", :realm_uuid => nil, :this => true)) }
  let(:connector) { Service.create!(connector_params.merge(:function => "connector", :secret => nil, :realm_uuid => nil)) }

  def app
    @app ||= Vidibus::Service::ConnectorApp
  end

  # Sends a signed request.
  def signed_request(method, url, params = nil)
    self.send(method, *Vidibus::Secure.sign_request(method, url, params, this.secret))
  end
  
  it "should fail for request methods other than GET, POST, PUT, and DELETE" do
    head "http://manager.local/connector"
    last_response.status.should eql(400)
  end

  it "should fail for paths other than /connector" do
    get "http://manager.local/something"
    last_response.status.should eql(400)
    last_response.body.should eql(%({"error":"This app must be configured to respond to /connector path."}))
  end

  describe "GET requests" do
    it "should fail without signature" do
      this and connector
      get "http://manager.local/connector"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should fail without valid signature" do
      this and connector
      get "http://manager.local/connector?sign=xxx"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should fail without this service" do
      connector
      get "http://manager.local/connector"
      last_response.status.should eql(400)
    end

    it "should return public data of this service as JSON" do
      this
      signed_request(:get, "http://manager.local/connector")
      last_response.body.should eql({:this => this.public_data}.to_json)
      last_response.status.should eql(200)
      last_response.content_type.should eql("text/javascript; charset=utf-8")
    end

    it "should also return public data of connector as JSON, if a connector is given" do
      this and connector
      signed_request(:get, "http://manager.local/connector")
      last_response.body.should eql({:this => this.public_data, :connector => connector.public_data}.to_json)
      last_response.content_type.should eql("text/javascript; charset=utf-8")
    end
  end

  describe "POST requests" do
    it "should fail if this service has already been set up" do
      this
      post "http://manager/connector", {}
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Service has already been set up."}))
    end

    it "should require Connector params" do
      post "http://manager.local/connector"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"No Connector data given."}))
    end

    it "should fail if Connector data is invalid" do
      post "http://manager.local/connector", {:connector => {:some => "thing"}}
      last_response.status.should eql(400)
      last_response.body.should match("Setting up the Connector failed:")
    end

    it "should set up a Connector" do
      mock(::Service).new(connector_params.merge(:function => "connector"))
      expect {
        post "http://manager.local/connector", {:connector => connector_params}
      }.to raise_error(NoMethodError, "undefined method `save' for nil:NilClass")
    end

    context "with Connector or Connector params" do
      before { connector }

      it "should not require Connector params if a Connector is present" do
        post "http://manager.local/connector"
        last_response.body.should_not eql(%({"error":"No Connector data given."}))
      end

      it "should require params for this service" do
        post "http://manager.local/connector"
        last_response.status.should eql(400)
        last_response.body.should eql(%({"error":"No data for this service given."}))
      end

      it "should fail if params for this service are invalid" do
        post "http://manager.local/connector", {:this => {:some => "thing"}}
        last_response.status.should eql(400)
        last_response.body.should match("Setting up this service failed:")
      end

      it "should set up this Service" do
        mock(::Service).new(this_params.merge(:this => true))
        expect {
          post "http://manager.local/connector", {:this => this_params}
        }.to raise_error(NoMethodError, "undefined method `secret=' for nil:NilClass")
      end

      it "should request a secret for this Service" do
        uri = "https://connector.local/services/#{this_params["uuid"]}/secret"
        stub_http_request(:get, uri).to_return(:status => 200)
        post "http://manager.local/connector", {:this => this_params}
      end

      it "should require a valid nonce to decrypt requested secret" do
        uri = "https://connector.local/services/#{this_params["uuid"]}/secret"
        params = {}
        stub_http_request(:get, uri).to_return(:status => 200, :body => %({"secret":"something","sign":"else"}))
        post "http://manager.local/connector", {:this => this_params.merge("nonce" => "invalid")}
        last_response.status.should eql(400)
        last_response.body.should match("Nonce is invalid.")
      end

      it "should decrypt requested secret and store it on the service object" do
        nonce = "hkO2ssb28Gks19s9h2hdhbBs83hdis"
        secret = "EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr"
        encrypted_secret = Vidibus::Secure.encrypt(secret, nonce)
        signature = Vidibus::Secure.sign(encrypted_secret, nonce)
        uri = "https://connector.local/services/#{this_params["uuid"]}/secret"
        params = {:secret => encrypted_secret, :sign => signature}
        stub_http_request(:get, uri).to_return(:status => 200, :body => params.to_json)
        post "http://manager.local/connector", {:this => this_params.merge("nonce" => nonce)}
        last_response.status.should eql(201)
        this = ::Service.where(:this => true).first
        this.should be_a(::Service)
        this.secret.should eql(secret)
      end
    end
  end

  describe "PUT requests" do
    it "should fail without signature" do
      this and connector
      put "http://manager.local/connector"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should fail without valid signature" do
      this and connector
      put "http://manager.local/connector?sign=xxx"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should succeed with valid signature" do
      this and connector
      signed_request(:put, "http://manager.local/connector")
      last_response.status.should eql(200)
    end

    it "should fail if this service is unconfigured" do
      get "http://manager.local/connector?sign=jkasdnkajdb"
      last_response.status.should eql(400)
    end

    it "should update existing services" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {:connector => {:url => url}})
      last_response.status.should eql(200)
      Service.local(:connector).url.should eql(url)
    end

    it "should fail if invalid data are given" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {:connector => {:secret => "not allowed"}})
      last_response.status.should eql(400)
      last_response.body.should match("Updating connector failed:")
    end

    it "should create new services" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector",
        {:uploader => {:url => "http://uploader.local", :uuid => "c0861d609247012d0a8b58b035f038ab", :secret => "A7q8Vzxgrk9xrw2FCnvV4bv01UP/LBUUM0lIGDmMcB2GsBTIqx", :realm_uuid => "12ab69f099a4012d4df558b035f038ab"}})
      last_response.status.should eql(200)
      Service.local(:uploader, "12ab69f099a4012d4df558b035f038ab").url.should eql("http://uploader.local")
    end
  end

  describe "DELETE requests" do
    it "should fail without signature" do
      this and connector
      delete "http://manager.local/connector"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should fail without valid signature" do
      this and connector
      delete "http://manager.local/connector?sign=xxx"
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Invalid signature."}))
    end

    it "should fail if this service is unconfigured" do
      delete "http://manager.local/connector?sign=jkasdnkajdb"
      last_response.status.should eql(400)
    end

    it "should fail if list of UUIDs is not given" do
      this and connector
      signed_request(:delete, "http://manager.local/connector", {})
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Provide list of :uuids"}))
    end

    it "should delete services given by UUID" do
      this and connector
      signed_request(:delete, "http://manager.local/connector", {:uuids =>["60dfef509a8e012d599558b035f038ab"]})
      last_response.status.should eql(200)
      Service.local(:connector).should be_nil
    end

    it "should not care if any given UUID is invalid" do
      this and connector
      signed_request(:delete, "http://manager.local/connector", {:uuids =>["invalid", "60dfef509a8e012d599558b035f038ab"]})
      last_response.status.should eql(200)
    end
  end
end
