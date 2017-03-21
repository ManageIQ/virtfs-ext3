# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'virtfs/ext3/version'

Gem::Specification.new do |spec|
  spec.name          = "virtfs-ext3"
  spec.version       = VirtFS::Ext3::VERSION
  spec.authors       = ["ManageIQ Developers"]

  spec.summary       = %q{An ext3 based filesystem module for VirtFS}
  spec.description   = %q{An ext3 based filesystem module for VirtFS}
  spec.homepage      = "https://github.com/ManageIQ/virtfs-ext3"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "memory_buffer"
  spec.add_dependency "binary_struct"
  spec.add_dependency "uuidtools"
  spec.add_dependency "rufus-lru"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "factory_girl"
end
