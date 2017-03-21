source 'https://rubygems.org'

gem 'virtfs', "~> 0.0.1", :git => "https://github.com/ManageIQ/virtfs.git", :branch => "master"

# Specify your gem's dependencies in virtfs-ext3.gemspec
gemspec

group :test do
  gem "codeclimate-test-reporter", :require => false
  gem "simplecov", :require => false

  gem 'virtfs-camcorderfs', "~> 0.1.0", :git => "https://github.com/movitto/virtfs-camcorderfs.git", :branch => "fixes"
  gem 'virt_disk', "~> 0.0.1", :git => "https://github.com/movitto/virt_disk.git", :branch => "initial"
end
