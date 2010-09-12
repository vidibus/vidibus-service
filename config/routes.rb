require "service/connector_app"

Rails.application.routes.draw do
  match "/connector" => Vidibus::Service::ConnectorApp
end
