# Shellac

Shellac is a simple caching reverse proxy. In it's current state, it is a
nominally usable proof of concept. It was built on top of Puma and Rack, and
it supports pluggable backend storage modules.

## Installation

    $ gem install shellac

## Usage

Use the `-h` flag to get help from `shellac`. If a storage engine is specified
with `-s`, then any command line flags and arguments supported by that storage
engine will also be listed.

```
$ shellac -s hash -h
shellac [OPTIONS]

shellac is a simple caching proxy server.

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

  -r 'foo.bar.com::\?(w+)$::https://github.com/'

  This can be specified multiple times. For complex route specs, it is better
  to use a configuration file.

-s ENGINE, --storageengine ENGINE:
  The storage engine to use for storing cached content.

-t MIN:MAX, --threads MIN:MAX:
  The minimum and maximum number of threads to run. Defaults to 0:10

-w COUNT, --workers COUNT:
  The number of worker processes to start.

-v, --version:
  Show the version of shellac.

--cache-trim-interval INTERVAL:
  The wait time in seconds between sweeps of the cache to ensure it isn't too large.

--max-cache-elements LENGTH:
  The maximum number of elements to store in the cache.

--max-cache-size SIZE:
  The maximum size, in bytes, of the cache.

```

For simple usage, routing rules can be specified right on the command line.
They are given in the format of:

```
DOMAIN[,DOMAIN2,DOMAINn]::MATCHRULE::DESTINATION
```

The DOMAIN section is a comma delimited list of one or more host names or IPs
which will match this rule.

THe MATCHRULE itself is simply a regular expression. The first rule that
matches stops checking of any remaining rules.

The DESTINATION can be either a simple string which will be evaulated with
normal Ruby string interpolation rules, allowing matched portions of the
MATCHRULE to be inserted, or it can be a chunk of ruby code to execute, the
return value of which should be a URL to proxy to.

If providing actual Ruby code, the `DESTINATION` should be prefixed with
`lambda:`. It is suggested that if a DESTINATION is to be determined by any
non-trivial code, that a configuration file be used instead of a command line
argument.

An example:

```
shellac -s hash -r '127.0.0.1::\?(.*)$::https://github.com/#{$1}' -t 2:16 -w 1
```

This will use the built in Ruby in memory Hash based storage engine (which is
also the default if `-s` is not specified. It is looking for requests on the
localhost IP, with a query string specified. If it finds a match, it uses the
query string to construct a github.com URL, and proxies that. It will run with
a minimum of two, and a maximum of 16 threads, and with a single worker
process.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake test` to run the tests. You can also run `bin/console` for an interactive
 prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/wyhaines/shellac.


## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

