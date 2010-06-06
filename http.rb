require 'net/https'

if RUBY_VERSION < '1.9'
  # Make it east to use some of the convenience methods using https
  module Net
    # backport from ruby1.9 boundled lib/net
    class HTTP
      begin
        require 'zlib'
        require 'stringio'  #for our purposes (unpacking gzip) lump these together
        HAVE_ZLIB=true
      rescue LoadError
        HAVE_ZLIB=false
      end
      
      def get(path, initheader = {}, dest = nil, &block) # :yield: +body_segment+
        res = nil
        if HAVE_ZLIB
          # FIXME: wired, sometimes the following error throwed:
          # undefined method `downcase' for {}:Hash
          unless  initheader.keys.any?{|k| k.downcase == "accept-encoding"}
            initheader["accept-encoding"] = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"
          end
          @compression = true
        end
        request(Get.new(path, initheader)) {|r|
          if r.key?("content-encoding") and @compression
            @compression = nil # Clear it till next set.
            the_body = r.read_body dest, &block
            case r["content-encoding"]
            when "gzip"
              r.body= Zlib::GzipReader.new(StringIO.new(the_body)).read
              r.delete("content-encoding")
            when "deflate"
              r.body= Zlib::Inflate.inflate(the_body);
              r.delete("content-encoding")
            when "identity"
              ; # nothing needed
            else 
              ; # Don't do anything dramatic, unless we need to later
            end
          else
            r.read_body dest, &block
          end
          res = r
        }
        unless @newimpl
          res.value
          return res, res.body
        end

        res
      end
    end

    class HTTPS < HTTP
      def initialize(address, port = nil)
        super(address, port)
        self.use_ssl = true
      end
    end

    class HTTPResponse
      # Because it may be necessary to modify the body, Eg, decompression
      # this method facilitates that.
      def body=(value)
        @body = value
      end
    end
  end
end
