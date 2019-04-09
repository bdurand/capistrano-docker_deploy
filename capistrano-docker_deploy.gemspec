# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "capistrano-docker_deploy/version"

Gem::Specification.new do |spec|
  spec.name          = "capistrano-docker_deploy"
  spec.version       = Capistrano::DockerDeploy::VERSION
  spec.authors       = ["Brian Durand"]
  spec.email         = ["bbdurand@gmail.com"]

  spec.summary       = %q{Use capistrano to deploy docker based applications.}
  spec.homepage      = "https://github.com/bdurand/capistrano-docker_deploy"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency, "capistrano", "~> 3.0"
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
end
