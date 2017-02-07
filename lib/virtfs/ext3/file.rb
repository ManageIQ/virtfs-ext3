module VirtFS::Ext3
  class File
    def initialize(dir_entry, superblock)
      @bs = superblock
      @de = dir_entry
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
       
  end # class File
end # module VirtFS::Fat32
