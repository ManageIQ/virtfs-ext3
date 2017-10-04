require 'ostruct'
require 'virtfs/block_io'
require 'virtfs/camcorderfs'

FactoryGirl.define do
  factory :ext, class: OpenStruct do
    recording_path "spec/cassettes/template.yml"

    mount_point '/mnt'

    root_dir ["d1", "d2", "f1", "f2", "fA", "fB", "lost+found"]

    glob_dir ['d1/s3', 'd1/sC']

    recording_root { "spec/virtual/" }

    recorder {
      r = VirtFS::CamcorderFS::FS.new(recording_path)
      r.root = recording_root
      r
    }

    path { "#{recording_root}/ext3.fs" }
  end
end
