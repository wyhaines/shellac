require 'optparse'
require 'shellac/storage_engine'
require 'shellac/config/task'
require 'shellac/config/tasklist'

module Shellac
  class ConfigClass
    def initialize
      @configuration = {}
      @configuration[:bind] = []
      @configuration[:minimum_threads] = 1
      @configuration[:maximum_threads] = 10
      @configuration[:worker_count] = 1
      @configuration[:routes] = Hash.new { |h, k| h[k] = [] }

      @meta_configuration = {}
      @meta_configuration[:helptext] = ''
    end

    def [](val)
      @configuration.has_key?(val) ? @configuration[val] : @meta_configuration[val]
    end

    def config
      @configuration
    end

    def meta
      @meta_configuration
    end

    def parse(parse_cl = true, additional_config = {}, additional_meta_config = {}, additional_tasks = nil)
      @configuration.merge! additional_config
      @meta_configuration.merge! additional_meta_config

      tasklist = parse_command_line if parse_cl

      tasklist = merge_task_lists(tasklist, additional_tasks) if additional_tasks

      run_task_list tasklist
    end

    def run_task_list( tasks )
      tasks = tasks.sort

      result = nil
      while tasks.any? do
        new_task = tasks.shift
        result = new_task.call # If any task returns a task list, fall out of execution
        break if TaskList === result
      end

      tasks = merge_task_lists(tasks, result) if TaskList === result # merge any new tasks into the remaining tasks

      run_task_list( tasks ) if tasks.any? # run any remaining tasks
    end

    def merge_task_lists(old_list, new_list)
      ( old_list + new_list ).sort
    end

    def parse_command_line
      call_list = TaskList.new

      options = OptionParser.new do |opts|
        opts.on( '-h', '--help' ) do
          exe = File.basename( $PROGRAM_NAME )
          @meta_configuration[:helptext] << <<-EHELP
#{exe} [OPTIONS]

#{exe} is a simple caching proxy server.

-h, --help:
  Show this help.

-b HOSTNAME[:PORT], --bind HOSTNAME[:PORT]:
  The hostname/IP and optionally the port to bind to. This defaults to 127.0.0.1:80 if it is not provided.

-c FILENAME, --config FILENAME:
  The configuration file to load.

-r ROUTESPEC, --route ROUTESPEC:
  Provides a routing specification for the proxy. A route spec is one or more
  host names or IPs, comma seperated, to match requests from, a regular
  expression to match against, and a target to proxy to:

  -r 'foo.bar.com::\?(\w+)$::https://github.com/\#{$1}'

  This can be specified multiple times. For complex route specs, it is better
  to use a configuration file.

-s ENGINE, --storageengine ENGINE:
  The storage engine to use for storing cached content.

-t MIN:MAX, --threads MIN:MAX:
  The minimum and maximum number of threads to run. Defaults to 0:10

-w COUNT, --workers COUNT:
  The number of worker processes to start.

-v, --version:
  Show the version of #{exe}.
EHELP
          call_list << Task.new(9999) { puts @meta_configuration[:helptext]; exit 0 }
        end

        opts.on( '-v', '--version') do
          exe = File.basename( $PROGRAM_NAME )
          @meta_configuration[:version] = "#{exe} v. #{Shellac::VERSION}"
          call_list << Task.new(9999) { puts @meta_configuration[:version]; exit 0 }
        end

        opts.on( '-c', '--config FILENAME' ) do |configfile|
          require 'yaml'
          call_list << Task.new(0) do
            parsed_config = YAML.load( File.read( File.expand_path( configfile ) ) )
            @configuration = parsed_config.merge( @configuration ) if Hash === parsed_config
          end
        end

        opts.on( '-s', '--storageengine ENGINE' ) do |storageengine|
          @configuration[:storageengine] = storageengine
          call_list << Task.new(1) do
            libname = "shellac/storage_engine/#{@configuration[:storageengine]}"
            setup_engine(:storageengine, libname)
          end
        end

        opts.on( '-t', '--threads THREADSPEC' ) do |threadspec|
          call_list << Task.new(9000) do
            min = 1
            max = 10
            if threadspec =~ /\s*(\d+)\s*:\s*(\d+)/
              min,max = [ $1.to_i > 0 ? $1.to_i : 1, $2.to_i > 0 ? $2.to_i : 10 ]
            else
              n = Integer( threadspec.to_i )
              max = n > 0 ? n : 10
            end
            @configuration[:minimum_threads] = min
            @configuration[:maximum_threads] = max
          end
        end

        opts.on( '-w', '--workers COUNT' ) do |worker_count|
          call_list << Task.new(9000) do
            count = Integer( worker_count.to_i )
            count = count > 0 ? count : 1
            @configuration[:worker_count] = count
          end
        end

        opts.on( '-r', '--route ROUTESPEC' ) do |routespec|
          # -r 'foo.bar.com::?(\w+)::https://github.com/#{$1}'
          #
          hosts,regexp,matchfunc = routespec.split(/::/,3)

          hosts = hosts.split(/,/).collect {|h| h.strip}

          regexp = Regexp.new( regexp )

          if matchfunc =~ /^lambda:(.*)$/m
            code = "#{$1}"
          else
            code = "\"#{matchfunc}\""
          end

          matchfunc = <<~ECODE
  lambda {|s,r|
    if s =~ r
      #{code}
    else
      nil
    end
  }
  ECODE
          matchfunc = Object.new.instance_eval(matchfunc)

          hosts.each do |h|
            @configuration[:routes][h] << {
              regexp: regexp,
              func: matchfunc
            }
          end
        end

       opts.on( '-b', '--bind HOST') do |host_and_port|
          if host_and_port =~ /^(\w+:\/\/)/ 
            protocol = $1
            host_and_port.gsub!(/^\w+:\/\//,'')
          else
            protocol = 'tcp://'
          end
          h,p = host_and_port.split(/:/,2)
          h = '127.0.0.1' if h.empty?
          p = '80' if p.empty?
          call_list << Task.new(9000) { @configuration[:bind] << "#{protocol}#{h}:#{p}" }
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
      ensure
        puts "adding default storage engine"
        unless @configuration[:storageengine]
          @configuration[:storageengine] = 'hash'
          call_list << Task.new(100) do
            libname = "shellac/storage_engine/#{@configuration[:storageengine]}"
            setup_engine(:storageengine, libname)
          end
        end
      end

      ARGV.replace( leftover_argv ) if leftover_argv.any?

      call_list
    end

    def classname(klass)
      parts = Array === klass ? klass : klass.split(/::/)
      parts.inject(::Object) {|o,n| o.const_get n}
    end

    def setup_engine(key, libname)
      require libname
      klass = classname( libname.split(/\//).collect {|s| s.capitalize} )
      @configuration[key] = klass.new
      @configuration[key].class.parse_command_line(@configuration, @meta_configuration) if @configuration[key].class.respond_to? :parse_command_line
    end

  end

  Config = ConfigClass.new
  Config.parse
end
