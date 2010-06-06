require 'http'
require 'reverse_proxy'

use Rack::ReverseProxy do
  # Forward the path /* to https://api.twitter.com/*
  reverse_proxy '/search', 'http://search.twitter.com/search'
  reverse_proxy '/', 'https://api.twitter.com/'
end

app = proc do |env|
  [ 200, {'Content-Type' => 'text/plain'}, "b" ]
end

run app
