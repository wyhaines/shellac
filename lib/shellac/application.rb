module Shellac
  class Launcher
    class << self
      def run
        puma_config = Puma::Configuration.new do |pconf|
          pconf.threads Config[:minimum_threads], Config[:maximum_threads]
          pconf.workers Config[:worker_count]
          pconf.app Application
        end

        Puma::Launcher.new(puma_config, events: Puma::Events.stdio).run
      end
    end
  end

  class ApplicationHelpers
    class << self
      def run
        puma_config = Puma::Configuration.new do |pconf|
          pconf.threads Config[:minimum_threads], Config[:maximum_threads]
          pconf.workers Config[:worker_count]
          pconf.app Application
        end
      end

      def request_headers( env )
        Hash[*env.select {|k,v| k.start_with? 'HTTP_'}
          .collect {|k,v| [k.sub(/^HTTP_/, ''), v]}
          .collect {|k,v| [k.split('_').collect(&:capitalize).join('-'), v]}
          .flatten]
      end
    end
  end

  Application = lambda { |env|
    hdrs = Shellac::ApplicationHelpers.request_headers( env )
    hdrs.delete("Host")
    response = nil

    original_url = ::Rack::Request.new( env ).url

    if Shellac::Config[:routes].has_key?( env["SERVER_NAME"] )
      Shellac::Config[:routes][ env["SERVER_NAME"] ].each do |route|
        if cached_response = Shellac::Config[:storageengine]["response:#{original_url}"]
          response = cached_response
        elsif to_url = route[:func].call(original_url, route[:regexp])
          fetched_response = HTTP.request(
            env["REQUEST_METHOD"].downcase.intern,
            to_url,
            HTTP.default_options.with_headers( hdrs )
          )
          fetched_body = fetched_response.body
          body = []
          if fetched_response.chunked?
            while partial = fetched_body.readpartial
              body << ( partial.bytesize.to_s(16) << "\r\n" << partial << "\r\n")
            end
            body << "0\r\n\r\n"
          else
            while partial = fetched_body.readpartial
              body << partial
            end
          end
          # Make this sexy and make it so that the exact caching key can be
          # specified instead of just crude path based caching.
          Shellac::Config[:storageengine]["response:#{original_url}"] = [
            fetched_response.status.code,
            fetched_response.headers.to_h,
            body
          ]

          response = [
            fetched_response.status.code,
            fetched_response.headers.to_h,
            body
          ]
          break
        end
      end
    end

    if response
      response
    else
      [200, {}, ["undefined"]]
    end
  }
end
