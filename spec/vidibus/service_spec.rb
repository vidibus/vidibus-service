require "spec_helper"

describe "Vidibus::Service::Error" do
  it "should be derived from StandardError" do
    Vidibus::Service::Error.superclass.should eql(StandardError)
  end
end

describe "Service" do
  it "should be a shorthand for Service.discover" do
    mock(Service).discover(:uploader, "realm")
    Service(:uploader, "realm")
  end
end
