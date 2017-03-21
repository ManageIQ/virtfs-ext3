module VirtFS::Ext3
  class File
    def initialize(file_obj, dir_entry, superblock)
      @bs       = superblock
      @de       = dir_entry
      @file_obj = file_obj
    end

    def to_h
      { :directory? => @de.dir?,
        :file?      => @de.file?,
        :symlink?   => @de.symlink? }
    end

    def fs
      @de.fs
    end

    def size
      @de.size
    end

    def close
      @de.close
    end

    def raw_read(start_byte, num_bytes)
      @file_obj.data.seek(start_byte, IO::SEEK_SET)
      @file_obj.data.read(num_bytes)
    end
  end # class File
end # module VirtFS::Ext3
