require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'virtfs'
require 'virtfs/ext3'
require 'virtfs-nativefs-thick'
require 'factory_girl'

# XXX bug in camcorder (missing dependency)
require 'fileutils'

require 'virtfs-camcorderfs'

require 'virt_disk'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    FactoryGirl.find_definitions
  end

  config.before(:all) do
    VirtFS.mount(VirtFS::NativeFS::Thick.new, "/")

    @orig_dir = Dir.pwd
    @ext = build(:ext,
                 recording_path: cassette_path)

    VirtFS.mount(@ext.recorder, File.expand_path("#{@ext.recording_root}"))
    VirtFS.activate!
    VirtFS.dir_chdir(@orig_dir)

    @root = @ext.mount_point
    block_dev = VirtDisk::Disk.new(VirtDisk::FileIo.new("#{@ext.path}"))
    extfs = VirtFS::Ext3::FS.new(block_dev)
    VirtFS.mount(extfs, @ext.mount_point)
  end

  config.after(:each) do
  end

  config.after(:all) do
    VirtFS.deactivate!
    VirtFS.umount(@ext.mount_point)
    VirtFS.dir_chdir("/")
    VirtFS.umount(File.expand_path("#{@ext.recording_root}"))
    VirtFS::umount("/")
  end
end
