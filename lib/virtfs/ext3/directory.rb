require_relative 'file_data'
require_relative 'directory_entry'

module VirtFS::Ext3
  class Directory
    ROOT_DIRECTORY = 2

    attr_accessor :fs

    def initialize(fs, sb, inode_num = ROOT_DIRECTORY)
      raise "nil superblock"   if sb.nil?
      raise "nil inode number" if inode_num.nil?
      @fs        = fs
      @sb        = sb
      @inode_num = inode_num
      @inode_obj = sb.get_inode(inode_num)
      @data      = sb.ext4? ? @inode_obj.read : FileData.new(@inode_obj, @sb).read
    end

    def close
    end

    def read(pos)
      return cache[pos], pos + 1
    end

    def cache
      @cache ||= glob_names.collect { |n| glob_entries[n].last }
    end

    def glob_names
      @ent_names ||= glob_entries.keys.compact.sort
    end

    def find_entry(name, type = nil)
      return nil unless glob_entries.key?(name)

      new_entry = @sb.new_dir_entry?
      glob_entries[name].each do |ent|
        ent.file_type = @sb.get_inode(ent.inode).file_mode_file_type unless new_entry
        return ent if ent.file_type == type || type.nil?
      end
      nil
    end

    private

    def glob_entries
      return @entries_by_name unless @entries_by_name.nil?

      @entries_by_name = {}
      return @entries_by_name if @data.nil?

      p = 0
      new_entry = @sb.new_dir_entry?
      loop do
        break if p > @data.length - 4
        break if @data[p, 4].nil?

        de = DirectoryEntry.new(fs, @data[p..-1], new_entry)
        raise "DirectoryEntry length cannot be 0" if de.len == 0

        @entries_by_name[de.name] ||= []
        @entries_by_name[de.name] << de

        p += de.len
      end

      @entries_by_name
    end
  end # class Directory
end # module VirtFS::Ext3
