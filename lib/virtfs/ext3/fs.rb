require_relative 'fs/dir_class_methods'
require_relative 'fs/file_class_methods'

module VirtFS::Ext3
  class FS
    include DirClassMethods
    include FileClassMethods

    attr_accessor :mount_point, :superblock, :root_dir

    attr_accessor :entry_cache, :dir_cache

    DEF_CACHE_SIZE = 50

    def self.match?(blk_device)
      begin
        blk_device.seek(0, IO::SEEK_SET)
        Superblock.new(blk_device)
        return true
      rescue => err
        return false
      end
    end

    def initialize(blk_device)
      blk_device.seek(0, IO::SEEK_SET)
      @superblock  = Superblock.new(blk_device)
      @root_dir    = Directory.new(self, superblock)
    end

    def entry_cache
      @entry_cache ||= LruHash.new(DEF_CACHE_SIZE)
    end

    def dir_cache
      @dir_cache ||= LruHash.new(DEF_CACHE_SIZE)
    end

    def cache_hits
      @cache_hits ||= 0
    end

    def thin_interface?
      true
    end

    def umount
      @mount_point = nil
    end

    # Wack leading drive leter & colon.
    def unnormalize_path(p)
      p[1] == 58 ? p[2, p.size] : p
    end
  end # class FS
end # module VirtFS::Ext3
