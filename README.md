# Vidibus::Service [![](http://travis-ci.org/vidibus/vidibus-service.png)](http://travis-ci.org/vidibus/vidibus-service) [![](http://stillmaintained.com/vidibus/vidibus-service.png)](http://stillmaintained.com/vidibus/vidibus-service)

DESCRIBE

This gem is part of [Vidibus](http://vidibus.org), an open source toolset for building distributed (video) applications.


## Installation

Add `gem "vidibus-service"` to your Gemfile. Then call `bundle install` on your console.


##  Requirements

In order to work properly this gem needs the route /connector to call a Rack app. Usually this 
route gets provided automatically but that may fail if your application has some sort of catch-all 
route. To check if the route works as expected, just call http://yourapp.com/connector and expect 
an error message like this:
  
```
This service has not been configured yet. Use your Connector to set it up.
```

If you don't see this error message, add the route manually at the top of your routes.rb:

```ruby
match "/connector" => Vidibus::Service::ConnectorApp
```


## Usage

DESCRIBE


## Copyright

&copy; 2010-2011 Andre Pankratz. See LICENSE for details.
