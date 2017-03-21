module VirtFS::Ext3
  class FileObject
    attr_accessor :data

    def initialize(path, dir_entry, superblock)
      @path = path
      @bs   = superblock
      @de   = dir_entry

      raise "File is directory: '#{@path}'" if !@de.nil? && @de.dir?

      #@mode = mode.downcase
      #if mode.include?("r")
        raise "File not found: '#{@path}'" if @de.nil?
        @inode = superblock.get_inode(@de.inode)
        @data  = FileData.new(@inode, superblock)
      #end
    end
  end
end # module VirtFS::Ext3
