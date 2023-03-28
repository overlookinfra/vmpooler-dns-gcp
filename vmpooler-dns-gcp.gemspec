# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vmpooler-dns-gcp/version'

Gem::Specification.new do |spec|
  spec.name    = "vmpooler-dns-gcp"
  spec.version = VmpoolerDnsGcp::VERSION
  spec.authors = ["Puppet by Perforce"]

  spec.summary = "Google Cloud DNS for VMPooler"
  spec.homepage = "https://github.com/puppetlabs/vmpooler-dns-gcp"
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/puppetlabs/vmpooler-dns-gcp/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir[ "lib/**/*" ]
  spec.require_paths = ["lib"]
  spec.add_dependency "googleauth", ">= 0.16.2", "< 1.3.0"
  spec.add_dependency "google-cloud-dns", "~> 0.35.1"
  spec.add_dependency 'vmpooler', '~> 3.0'

  # Testing dependencies
  spec.add_development_dependency 'mock_redis', '>= 0.17.0'
  spec.add_development_dependency 'rspec', '>= 3.2'
  spec.add_development_dependency 'rubocop', '~> 1.1.0'
  spec.add_development_dependency 'simplecov', '>= 0.11.2'
end
