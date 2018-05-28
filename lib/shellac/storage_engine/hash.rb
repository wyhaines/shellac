require 'shellac/storage_engine'

module Shellac
  class Storage_engine
    class Hash < Shellac::Storage_engine::Base

      def self.parse_command_line(configuration, meta_configuration)
        call_list = Shellac::ConfigClass::TaskList.new

        meta_configuration[:helptext] << <<-EHELP

--cache-trim-interval INTERVAL:
  The wait time in seconds between sweeps of the cache to ensure it isn't too large.

--max-cache-elements LENGTH:
  The maximum number of elements to store in the cache.

--max-cache-size SIZE:
  The maximum size, in bytes, of the cache.

EHELP

        options = OptionParser.new do |opts|
          opts.on( '--cache-trim-interval INTERVAL' ) do |interval|
            call_list << Shellac::ConfigClass::Task.new(9000) do
              n = Integer( interval.to_i )
              configuration[:cache_trim_interval] = n
            end
          end

          opts.on( '--max-cache-elements LENGTH' ) do |len|
            call_list << Shellac::ConfigClass::Task.new(9000) do
              n = Integer( len.to_i )
              configuration[:cache_max_elements] = n
            end
          end

          opts.on( '--max-cache-size SIZE' ) do |size|
            call_list << Shellac::ConfigClass::Task.new(9000) do
              n = Integer( size.to_i )
              n = n > 0 ? n : 1024 * 1024 * 20
              configuration[:cache_max_size] = n
            end
          end
        end

        leftover_argv = []

        begin
          options.parse!(ARGV)
        rescue OptionParser::InvalidOption => e
          e.recover ARGV
          leftover_argv << ARGV.shift
          leftover_argv << ARGV.shift if ARGV.any? && ( ARGV.first[0..0] != '-' )
          retry
        end

        ARGV.replace( leftover_argv ) if leftover_argv.any?

        call_list
      end
    end
  end
end
