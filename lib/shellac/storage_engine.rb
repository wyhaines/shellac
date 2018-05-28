module Shellac
  class Storage_engine
    class Base
      def initialize( args = {} )
        @config = _default_args.merge( args )
        @cache_control_thread = new_cache_control_thread
        @cache_size = 0
        @cache = {}
      end

      def _default_args
        {
          preload: {},
          length_limit: 1000,
          size_limit: 1024 * 1024 * 20,
          trim_interval: 30 
        }
      end

      def new_cache_control_thread
        Thread.new do
          sleep( @config[ :trim_interval ] )

          while @cache_size > @config[ :size_limit ]
            # Trim Cache -- stupid algorithm just randomly deletes things
            # until it is small enough
            sz = @cache.delete( @cache.keys[ rand( @cache.length ) ] ).to_s.length
            @cache_size -= sz
          end
        end
      end

      def []( k )
        @cache[ k ]
      end

      def get( k )
        self[ k ]
      end

      def []=( k, v )
        @cache_size += v.to_s.length
        @cache[ k ] = v
      end

      def set( k, v )
        self[ k ] = v
      end

      def keys
        @cache.keys
      end

      def delete( k )
        @cache.delete( k )
      end

      def length
        @cache.length
      end
      alias_method :size, :length

    end
  end
end
