# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shellac/version'

Gem::Specification.new do |spec|
  spec.name          = "shellacrb"
  spec.version       = Shellac::VERSION
  spec.authors       = ["Kirk Haines"]
  spec.email         = ["kirk-haines@cookpad.com"]

  spec.summary       = %q{A simple caching proxy, written in Ruby.}
  spec.description   = %q{A simple caching proxy, like Varnish, but...not. And written in Ruby.}
  spec.homepage      = "https://github.com/wyhaines/shellac"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"

  spec.add_runtime_dependency "puma", "~> 3.11"
  spec.add_runtime_dependency "http", "~> 3.3"
  spec.add_runtime_dependency "rack", "~> 2.0"
end
