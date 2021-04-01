# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pact/retreaty/version'

Gem::Specification.new do |spec|
  spec.name          = "pact-retreaty"
  spec.version       = Pact::Retreaty::VERSION
  spec.authors       = ["Simon Hildebrandt"]
  spec.email         = ["simonhildebrandt@fairfaxmedia.com.au"]

  spec.summary       = %q{Easily share pacts via S3.}
  spec.description   = %q{Easily share pacts via S3.}
  spec.homepage      = "https://github.com/fairfaxmedia/pact-retreaty"
  spec.license       = "MIT"
  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency('aws-sdk-s3', '~> 1')
  spec.add_dependency('pact')

  spec.add_development_dependency "bundler", '~> 2.1'
  spec.add_development_dependency "rake", '~> 13.0'
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
end

