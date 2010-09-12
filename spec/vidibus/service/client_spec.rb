require "spec_helper"

describe Vidibus::Service::Client do
  let(:this) {Service.create!(:function => "manager", :url => "http://manager.local", :uuid => "973a8710926e012d0a8c58b035f038ab", :secret => "EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr", :this => true, :realm_uuid => nil)}
  let(:uploader) {Service.create!(:function => "uploader", :url => "http://uploader.local", :uuid => "ddeb4500668e012d47bb58b035f038ab", :secret => "XaDai5nz1sDbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr", :realm_uuid => "e33f0d9093f9012d0dbc58b035f038ab")}
  let(:client) { this; Vidibus::Service::Client.new(uploader) }

  describe "#initialize" do
    it "should require a service object" do
      expect { Vidibus::Service::Client.new(:uploader) }.should raise_error(Vidibus::Service::Client::ServiceError)
    end

    it "should require this" do
      expect { Vidibus::Service::Client.new(uploader) }.should raise_error(Service::ConfigurationError)
    end

    it "should set URL of given service as base_uri" do
      this
      client = Vidibus::Service::Client.new(uploader)
      client.base_uri.should eql(uploader.url)
    end
  end

  describe "#get" do
    it "should load data via GET" do
      stub_http_request(:get, "http://uploader.local/success").
        with(:query => {:realm => uploader.realm_uuid, :service => this.uuid, :sign => "43a4d004c55113131f198c9772760467727b5564de74aacfcf4686751e3d388a"}).
          to_return(:status => 200, :body => %({"hot":"stuff"}))
      response = client.get("/success")
      response.code.should eql(200)
      response.should eql({"hot" => "stuff"})
    end
    
    it "should handle non-JSON responses" do
      stub_http_request(:get, "http://uploader.local/success").
        with(:query => {:realm => uploader.realm_uuid, :service => this.uuid, :sign => "43a4d004c55113131f198c9772760467727b5564de74aacfcf4686751e3d388a"}).
          to_return(:status => 200, :body => "something")
      response = client.get("/success")
      response.code.should eql(200)
      response.should eql("something")
    end
  end

  describe "#post" do
    it "should send data via POST" do
      stub_http_request(:post, "http://uploader.local/create").
        with(:query => {:some => "thing", :realm => uploader.realm_uuid, :service => this.uuid, :sign => "9c16bc080f106c73f28813f02899be97301b1b627d25a65d52f68a3c9732559d"}).
          to_return(:status => 200)
      response = client.post("/create", :query => {:some => "thing"})
      response.code.should eql(200)
    end
  end

  describe "#put" do
    it "should send data via PUT" do
      stub_http_request(:put, "http://uploader.local/update").
        with(:query => {:some => "thing", :realm => uploader.realm_uuid, :service => this.uuid, :sign => "57e75433e49d9ef160b03b9e6a7d91fbd6523471eb8e7e36bb861066101f0903"}).
          to_return(:status => 200)
      response = client.put("/update", :query => {:some => "thing"})
      response.code.should eql(200)
    end
  end

  describe "#delete" do
    it "should send a DELETE request" do
      stub_http_request(:delete, "http://uploader.local/record/123").
        with(:query => {:realm => uploader.realm_uuid, :service => this.uuid, :sign => "b9c026563d950a719e168c6f072f75c13f4843b82274f57f6e5a9a4cd8e0cc64"}).
          to_return(:status => 200)
      response = client.delete("/record/123")
      response.code.should eql(200)
    end
  end
end
