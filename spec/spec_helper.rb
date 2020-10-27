require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'virtfs'
require 'virtfs/ext3'
require 'virtfs-nativefs-thick'
require 'factory_bot'

# XXX bug in camcorder (missing dependency)
require 'fileutils'

require 'virtfs-camcorderfs'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:all) do
    VirtFS.mount(VirtFS::NativeFS::Thick.new, "/")

    @ext = build(:ext,
                 recording_path: cassette_path,
                 #virtual_root: Dir.pwd)
                  virtual_root: '/home/mmorsi/workspace/cfme/virtfs-ext3')

    VirtFS.mount(@ext.recorder, @ext.recording_root)

    @root = @ext.mount_point
    block_dev = VirtFS::BlockIO.new(VirtDisk::BlockFile.new(@ext.path))
    extfs = VirtFS::Ext3::FS.new(block_dev)
    VirtFS.mount(extfs, @ext.mount_point)
  end

  config.after(:each) do
    VirtFS.dir_chdir('/')
  end

  config.after(:all) do
    VirtFS.umount(@ext.mount_point)
    VirtFS.umount(@ext.recording_root)
    VirtFS::umount("/")
  end
end
