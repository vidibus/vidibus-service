require "spec_helper.rb"

describe "Vidibus::Service::ConnectorApp" do
  include Rack::Test::Methods
  let(:this_uuid) {"344b4b8088fb012dd3e558b035f038ab"}
  let(:this_uri) {"https://connector.local/services/#{this_uuid}/secret"}
  let(:connector_uuid) {"60dfef509a8e012d599558b035f038ab"}

  let(:nonce) {"hkO2ssb28Gks19s9h2hdhbBs83hdis"}
  let(:secret) {"EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr"}
  let(:encrypted_secret) {Vidibus::Secure.encrypt(secret, nonce)}
  let(:signature) {Vidibus::Secure.sign(encrypted_secret, nonce)}

  let(:this_params) {{:uuid => this_uuid, :url => "http://manager.local", :function => "manager", :this => true}}
  let(:connector_params) {{:uuid => connector_uuid, :url => "https://connector.local", :function => "connector", :secret => nil, :realm_uuid => nil}}
  let(:this) {Service.create!(this_params.merge(:secret => "EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr", :realm_uuid => nil))}
  let(:connector) {Service.create!(connector_params)}
  let(:uploader_params) {{:uuid => "c0861d609247012d0a8b58b035f038ab", :url => "http://uploader.local", :function => "uploader"}}
  let(:uploader) {Service.create!(uploader_params.merge(:secret => "whatever", :realm_uuid => "408411702613012e39ec58b035f038ab"))}

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
      last_response.body.should match("This service has already been set up.")
    end

    context "without Connector or Connector params" do
      it "should require Connector params" do
        post "http://manager.local/connector"
        last_response.status.should eql(400)
        last_response.body.should match("No Connector data given.")
      end
    end

    context "with Connector params" do
      before {stub.any_instance_of(Vidibus::Service::ConnectorApp).create_this!}

      it "should fail if params are invalid given" do
        post "http://manager.local/connector", {connector_uuid => connector_params.except(:url)}
        last_response.status.should eql(400)
        last_response.body.should match("Setting up the Connector failed:")
      end

      it "should set up a Connector with valid params" do
        post "http://manager.local/connector", {connector_uuid => connector_params}
        last_response.status.should eql(201)
        connector = Service.where(:uuid => connector_params[:uuid]).first
        connector.should be_a(Service)
      end

      it "should accept any value as key" do
        post "http://manager.local/connector", {"something" => connector_params}
        last_response.status.should eql(201)
      end

      it "should not create another connector if one already exists" do
        connector
        post "http://manager.local/connector", {connector_uuid => connector_params}
        last_response.status.should eql(201)
      end
    end

    context "with existing Connector" do
      let(:secret_data) {{"secret" => encrypted_secret, "sign" => signature}}
      let(:stub_secret_request!) {stub(HTTParty).get(this_uri, :format => :json) {secret_data}}
      before { connector }

      it "should not require Connector params if a Connector is present" do
        post "http://manager.local/connector"
        last_response.body.should_not match("No Connector data given.")
      end

      it "should require params for this service" do
        post "http://manager.local/connector"
        last_response.status.should eql(400)
        last_response.body.should match("No data given for this service.")
      end

      it "should fail if params for this service are invalid" do
        post "http://manager.local/connector", {this_uuid => this_params.except(:function)}
        last_response.status.should eql(400)
        last_response.body.should match("Setting up this service failed:")
      end

      it "should fail if a secret is given" do
        post "http://manager.local/connector", {this_uuid => this_params.merge(:secret => "something")}
        last_response.status.should eql(400)
        last_response.body.should match("Setting a secret for this service is not allowed!")
      end

      it "should fail unless a nonce is given" do
        post "http://manager.local/connector", {this_uuid => this_params}
        last_response.status.should eql(400)
        last_response.body.should match("No nonce given.")
      end

      it "should request a secret for this Service" do
        mock(HTTParty).get(this_uri, :format => :json) {{}}
        stub.any_instance_of(Vidibus::Service::ConnectorApp).decrypt_secret! {"ok"}
        post "http://manager.local/connector", {this_uuid => this_params.merge(:nonce => nonce)}
      end

      it "should fail if sign cannot be validated with nonce" do
        stub_secret_request!
        post "http://manager.local/connector", {this_uuid => this_params.merge(:nonce => "invalid")}
        last_response.status.should eql(400)
        last_response.body.should match("Nonce is invalid.")
      end

      it "should decrypt the secret with a valid nonce" do
        stub_secret_request!
        mock.any_instance_of(Service).secret=(secret)
        post "http://manager.local/connector", {this_uuid => this_params.merge(:nonce => nonce)}
      end

      it "should set up this Service with valid params" do
        stub_secret_request!
        post "http://manager.local/connector", {connector_uuid => this_params.merge(:nonce => nonce)}
        stub(HTTParty).get(this_uri, :format => :json) {secret_data}
        last_response.status.should eql(201)
        this = Service.where(:this => true).first
        this.should be_a(Service)
        this.secret.should eql(secret)
        this.url.should eql("http://manager.local")
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

    it "should update an existing service without realm_uuid" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {connector.uuid => {:url => url}})
      last_response.status.should eql(200)
      Service.local(:connector).url.should eql(url)
    end

    it "should update an existing service with given realm_uuid" do
      this and connector and uploader
      url = "http://newuploader.local"
      signed_request(:put, "http://manager.local/connector", {uploader.uuid => {:url => url, :realm_uuid => uploader.realm_uuid}})
      last_response.status.should eql(200)
      Service.local(:uploader, uploader.realm_uuid).url.should eql(url)
    end

    it "should not update existing services with a different realm_uuid" do
      this and connector and uploader
      different_realm_uuid = "e75234809111012d05ac58b035f038ab"
      different_uploader = Service.create!(uploader_params.merge(:secret => "whatever", :realm_uuid => different_realm_uuid))
      signed_request(:put, "http://manager.local/connector", {uploader.uuid => {:url => "http://newuploader.local", :realm_uuid => uploader.realm_uuid}})
      last_response.status.should eql(200)
      Service.local(:uploader, different_realm_uuid).url.should eql(different_uploader.url)
    end

    it "should update all existing services with matching uuid" do
      this and connector and uploader
      another_uploader = Service.create!(uploader_params.merge(:realm_uuid => "e75234809111012d05ac58b035f038ab", :secret => "whatever"))
      signed_request(:put, "http://manager.local/connector", {uploader.uuid => {:function => "fancy"}})
      last_response.status.should eql(200)
      Service.where(:function => "fancy").to_a.should have(2).services
    end

    it "should fail if no uuid is given" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {:url => url})
      last_response.status.should eql(400)
      last_response.body.should match("Updating failed: 'url' is not a valid UUID.")
    end

    it "should fail if an invalid uuid is given" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {"c0861d609247012d0a8b58b035f038ab" => {:url => url}})
      last_response.status.should eql(400)
      last_response.body.should match("Updating service c0861d609247012d0a8b58b035f038ab failed:")
    end

    it "should fail if invalid data is given" do
      this and connector
      url = "http://newconnector.local"
      signed_request(:put, "http://manager.local/connector", {connector.uuid => {:secret => "not allowed"}})
      last_response.status.should eql(400)
      last_response.body.should match("Updating service 60dfef509a8e012d599558b035f038ab failed:")
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
      last_response.body.should eql(%({"error":"Provide list of UUIDs of services to delete."}))
    end

    it "should fail if deleting of a service fails" do
      this and connector
      stub.any_instance_of(Service).destroy {false} # Would be nice: errors.add(:base, "Failed")
      signed_request(:delete, "http://manager.local/connector", {:uuids =>[connector_uuid]})
      last_response.status.should eql(400)
      last_response.body.should eql(%({"error":"Deleting service 60dfef509a8e012d599558b035f038ab failed: "}))
    end

    it "should delete services given by UUID" do
      this and connector
      signed_request(:delete, "http://manager.local/connector", {:uuids =>[connector_uuid]})
      last_response.status.should eql(200)
      Service.local(:connector).should be_nil
    end

    it "should not care if any given UUID is invalid" do
      this and connector
      signed_request(:delete, "http://manager.local/connector", {:uuids =>["invalid", connector_uuid]})
      last_response.status.should eql(200)
    end
  end
end
