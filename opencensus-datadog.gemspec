
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "opencensus/datadog/version"

Gem::Specification.new do |spec|
  spec.name          = "opencensus-datadog"
  spec.version       = OpenCensus::Datadog::VERSION
  spec.authors       = ["Wantedly, Inc.", "Yuichi Saito"]
  spec.email         = ["dev@wantedly.com", "munisystem@gmail.com"]

  spec.summary       = "Datadog APM exporter for OpenCensus"
  spec.description   = "Datadog APM exporter for OpenCensus"
  spec.homepage      = "https://github.com/wantedly/opencensus-datadog"
  spec.license       = "MIT"

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'msgpack'
  spec.add_dependency 'opencensus'
  spec.add_dependency 'ddtrace', '< 1.0'

  spec.add_development_dependency "bundler", ">= 1.16", "< 3.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
