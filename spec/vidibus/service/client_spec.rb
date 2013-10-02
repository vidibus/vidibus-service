require 'spec_helper'

describe Vidibus::Service::Client do
  let(:this) do
    Service.create!({
      :function => 'manager',
      :url => 'http://manager.local',
      :uuid => '973a8710926e012d0a8c58b035f038ab',
      :secret => 'EaDai5nz16DbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr',
      :this => true, :realm_uuid => nil
    })
  end
  let(:uploader) do
    Service.create!({
      :function => 'uploader',
      :url => 'http://uploader.local',
      :uuid => 'ddeb4500668e012d47bb58b035f038ab',
      :secret => 'XaDai5nz1sDbQTWQuuFdd4WcAiZYRPDwZTn2IQeXbPE4yBg3rr',
      :realm_uuid => 'e33f0d9093f9012d0dbc58b035f038ab'
    })
  end
  let(:client) do
    this
    Vidibus::Service::Client.new(uploader)
  end

  describe '#initialize' do
    it 'should require a service object' do
      expect { Vidibus::Service::Client.new(:uploader) }.
        to raise_error(Vidibus::Service::Client::ServiceError)
    end

    it 'should require an url' do
      stub(uploader).url {}
      expect { Vidibus::Service::Client.new(uploader) }.
        to raise_error(Vidibus::Service::Client::ServiceError)
    end

    it 'should require this' do
      expect { Vidibus::Service::Client.new(uploader) }.
        to raise_error(Vidibus::Service::ConfigurationError)
    end

    it 'should set URL of given service as base_uri' do
      this
      client = Vidibus::Service::Client.new(uploader)
      client.base_uri.should eql(uploader.url)
    end
  end

  describe '#get' do
    let(:query) do
      {
        :realm => uploader.realm_uuid,
        :service => this.uuid,
        :sign => '992a345de059df951ce517f9ad0dc9e3ae2f95a78fe6d140c24cbcc1d7a1840b'
      }
    end

    it 'should load data via GET' do
      stub_http_request(:get, 'http://uploader.local/success').
        with(:query => query).
        to_return(:status => 200, :body => %({'hot':'stuff'}))
      response = client.get('/success')
      response.code.should eql(200)
      response.should eql({'hot' => 'stuff'})
    end

    it 'should handle non-JSON responses' do
      stub_http_request(:get, 'http://uploader.local/success').
        with(:query => query).
        to_return(:status => 200, :body => 'something')
      response = client.get('/success')
      response.code.should eql(200)
      response.should eql('something')
    end

    it 'should turn a relative path into an absolute one' do
      stub_http_request(:get, 'http://uploader.local/success').
        with(:query => query)
      client.get('success')
    end

    it 'should re-raise a StandardError' do
      stub(Vidibus::Service::Client).get { raise(StandardError) }
      expect { client.get('success') }.
        to raise_error(Vidibus::Service::Client::RequestError)
    end

    it 'should re-raise an Exception' do
      stub(Vidibus::Service::Client).get { raise(Exception) }
      expect { client.get('success') }.
        to raise_error(Vidibus::Service::Client::RequestError)
    end

    it 'should should set original backtrace on error' do
      stub(Vidibus::Service::Client).get { raise(StandardError) }
      begin
        client.get('success')
      rescue Vidibus::Service::Client::RequestError => e
        e.backtrace.first.should match('/client_spec.rb:')
      end
    end
  end

  describe '#post' do
    it 'should send data via POST' do
      stub_http_request(:post, 'http://uploader.local/create').
        with(:body => {
          :some => 'thing',
          :realm => uploader.realm_uuid,
          :service => this.uuid,
          :sign => '2b8754f4e790d0a91ff955e4f599a9cacd84e73a93c2825962afbe738158ccdb'
        }).to_return(:status => 200)
      response = client.post('/create', :body => {:some => 'thing'})
      response.code.should eql(200)
    end
  end

  describe '#put' do
    it 'should send data via PUT' do
      stub_http_request(:put, 'http://uploader.local/update').
        with(:body => {
          :some => 'thing',
          :realm => uploader.realm_uuid,
          :service => this.uuid,
          :sign => '1c498f6dab0eedd9d14a69e2a0d508366158a80cf40aea4130e311ce9485012c'
        }).to_return(:status => 200)
      response = client.put('/update', :body => {:some => 'thing'})
      response.code.should eql(200)
    end
  end

  describe '#delete' do
    it 'should send a DELETE request' do
      stub_http_request(:delete, 'http://uploader.local/record/123').
        with(:query => {
          :realm => uploader.realm_uuid,
          :service => this.uuid,
          :sign => 'fbdbd124c9ec526fe2fc382a77ead820bedda586acf68de6e442e523a384bd44'
        }).to_return(:status => 200)
      response = client.delete('/record/123')
      response.code.should eql(200)
    end
  end
end
