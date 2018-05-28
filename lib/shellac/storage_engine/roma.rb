module Shellac
  class StorageEngine
    class Roma << Shellac::StorageEngine
      def self.parse_command_line(configuration, meta_configuration)
        call_list = Shellac::Config::TaskList.new

        meta_configuration[:helptext] << <<-EHELP
--processes COUNT:
  The number of processes to fork. Defaults to 1.

-s SIZE|MINSIZE,MAXSIZE, --pool-size SIZE|MINSIZE,MAXSIZE:
  The size of the thread pool to create. If unset, Scrawls will spawn a thread for each request. If given two comman separated numbers, those numbers will be interpreted to be the minimum and maximum size of the thread pool. Scrawls will spawn new threads as needed, to the maximum number, if all threads are busy, and will later reduce the size of the thread pool back down toward the minimum size if the threads become idle.

EHELP

        options = OptionParser.new do |opts|
          opts.on( '--processes COUNT' ) do |count|
            call_list << SimpleRubyWebServer::Config::Task.new(9000) { n = Integer( count.to_i ); n = n > 0 ? n : 1; configuration[:processes] = n }
          end

          opts.on( '--s', '--pool-size SIZE' ) do |size|
            call_list << SimpleRubyWebServer::Config::Task.new(9000) do
              n = nil

              if size =~ /\s*(\d+)\s*,\s*(\d+)/
                n = [ $1.to_i, $2.to_i > 0 ? $2.to_i : 1 ]
              else
                n = Integer( size.to_i )
                n = n > 0 ? [ n ] : nil
              end

              configuration[:thread_pool] = n
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
