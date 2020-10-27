require 'ostruct'
require 'virtfs/block_io'
require 'virtfs/camcorderfs'
require 'virt_disk/block_file'

FactoryBot.define do
  factory :ext, class: OpenStruct do
    virtual_root ''

    recording_path "spec/cassettes/template.yml"

    ###

    mount_point '/mnt'

    root_dir ["d1", "d2", "f1", "f2", "fA", "fB", "lost+found"]

    glob_dir ['d1/s3', 'd1/sC']

    recording_root { "#{virtual_root}/images" }

    recorder {
      rec = VirtFS::CamcorderFS::FS.new(File.expand_path(recording_path))
      rec.root = recording_root
      rec
    }

    path { "#{virtual_root}/images/ext3.fs" }
  end
end
