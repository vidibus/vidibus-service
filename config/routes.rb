require 'vidibus/service/connector_app'

Rails.application.routes.draw do
  match '/connector' => Vidibus::Service::ConnectorApp, :via => [:get, :post, :put, :delete]
end
