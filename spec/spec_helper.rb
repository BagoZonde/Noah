require File.join(File.dirname(__FILE__), '..', 'lib', 'noah')
require File.join(File.dirname(__FILE__), '..', 'lib', 'noah', 'app')
require 'rspec'
require 'rack/test'
ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://localhost:6379/3'
Ohm::connect

RSpec.configure do |config|
  config.color_enabled = true
  config.formatter = "documentation"
  config.before(:each, :reset_redis => true) { Ohm::redis.flushdb }
  config.after(:each, :reset_redis => true) {Ohm::redis.flushdb }
  config.after(:all, :populate_sample_data => true) {Ohm::redis.flushdb }
  config.before(:all, :populate_sample_data => true) do
    Ohm::redis.flushdb
    Noah::Watcher.create :endpoint => "dummy://applications", :pattern => "//noah/applications"
    Noah::Watcher.create :endpoint => "dummy://configurations", :pattern => "//noah/configurations"
    Noah::Watcher.create :endpoint => "dummy://hosts", :pattern => "//noah/hosts"
    Noah::Watcher.create :endpoint => "dummy://services", :pattern => "//noah/services"
    Noah::Watcher.create :endpoint => "dummy://ephemerals", :pattern => "//noah/ephemerals"
    h = Noah::Host.create(:name => 'localhost', :status => "up")
    if h.save
      %w[redis noah].each do |service|
        s = Noah::Service.create(:name => service, :status => "up", :host => h)
        h.services << s
      end
    end

    a = Noah::Application.create(:name => 'noah')
    if a.save
      cr = Noah::Configuration.create(:name => 'redis', :format => 'string', :body => 'redis://127.0.0.1:6379/0')
      ch = Noah::Configuration.create(:name => 'host', :format => 'string', :body => 'localhost')
      cp = Noah::Configuration.create(:name => 'port', :format => 'string', :body => '9292')
      %w[cr ch cp].each do |c|
        a.configurations << eval(c)
      end
    end

    my_yaml = <<EOY
    development:
      database: development_database
      adapter: mysql
      username: dev_user
      password: dev_password
EOY
    my_json = <<EOJ
    {
      "id":"hostname",
      "data":"localhost"
    }
EOJ

    a1 = Noah::Application.create(:name => 'myrailsapp1')
    if a1.save
      c1 = Noah::Configuration.create(:name => 'database.yml', :format => 'yaml', :body => my_yaml)
      a1.configurations << c1
    end

    a2 = Noah::Application.create(:name => 'myrestapp1')
    if a2.save
      c2 = Noah::Configuration.create(:name => 'config.json', :format => 'json', :body => my_json)
      a2.configurations << c2
    end
  end
  config.include Rack::Test::Methods
end

def app
  Noah::App
end

RSpec::Matchers.define :return_json do
  match do |last_response|
    last_response.headers["Content-Type"].should =~ /^application\/json;.*/
    response = JSON.parse(last_response.body)
  end

  failure_message_for_should do
    "Response was not valid JSON"
  end  
end

RSpec::Matchers.define :be_missing do
  match do |last_response|
    last_response.headers["Content-Type"].should =~ /^application\/json;.*/
    last_response.status.should == 404
    response = JSON.parse(last_response.body)
    response["result"].should == "failure"
    response["error_message"].should == "Resource not found"
  end
end

RSpec::Matchers.define :be_invalid do
  match do |last_response|
    last_response.headers["Content-Type"].should =~ /^application\/json;.*/
    response = JSON.parse(last_response.body)
    response["result"].should == "failure"
    response["error_message"].should == "Missing Parameters"
  end
end  
