require 'net/http'

module Rack
  class ReverseProxy
    def initialize(app = nil, &b)
      @app = app || lambda { [404, [], []] }
      @paths = []
      instance_eval &b if block_given?
    end

    def call(env)
      rackreq = Rack::Request.new(env)
      matcher, url = get_matcher_and_url rackreq.fullpath
      
      return @app.call(env) if matcher.nil?

      uri = get_uri(url, matcher, rackreq.fullpath)
      method = rackreq.request_method.capitalize

      proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

      if proxy_request.request_body_permitted? and rackreq.body
        proxy_request.body_stream = rackreq.body
        proxy_request.content_length = rackreq.content_length
        proxy_request.content_type = rackreq.content_type
      end

      %w(Accept Accept-Encoding Accept-Charset
        X-Requested-With Referer User-Agent Cookie
        Authorization
        ).each do |header|
        key = "HTTP_#{header.upcase.gsub('-', '_')}"
        proxy_request[header] = rackreq.env[key] if rackreq.env[key]
      end
      
      proxy_request["X-Forwarded-For"] = (rackreq.env["X-Forwarded-For"].to_s.split(/, +/) + [rackreq.ip]).join(", ")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"  # enable SSL/TLS
      rp_response = http.start do |client|
        client.request(proxy_request)
      end

      headers = {}
      rp_response.each_header do |k,v|
        headers[k] = v unless k.to_s =~ /content-length|transfer-encoding/i
      end

      [rp_response.code.to_i, headers, rp_response.read_body]
    end
    
    private

    def get_matcher_and_url path
      matches = @paths.select do |config|
        match_path(path, config[0])
      end

      if matches.length < 1
        nil
      elsif matches.length > 1
        matches.first.map{|a| a.dup}
      else
        matches.first.map{|a| a.dup}
      end
    end

    def match_path(path, matcher)
      if matcher.is_a?(Regexp)
        path.match(matcher)
      else
        path.match(/^#{matcher.to_s}/)
      end
    end

    def get_uri(url, matcher, path)
      if url =~/\$\d/
        match_path(path, matcher).to_a.each_with_index { |m, i| url.gsub!("$#{i.to_s}", m) }
        URI(url)
      else
        URI.join(url, path)
      end
    end

    def reverse_proxy matcher, url
      raise GenericProxyURI.new(url) if matcher.is_a?(String) && URI(url).class == URI::Generic
      @paths.push([matcher, url])
    end
  end

  class GenericProxyURI < Exception
    attr_reader :url

    def intialize(url)
      @url = url
    end

    def to_s
      %Q(Your URL "#{@url}" is too generic. Did you mean "http://#{@url}"?)
    end
  end

end
