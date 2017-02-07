require 'binary_struct'

module VirtFS::Ext3
  class DirectoryEntry
    FILE_TYPES = {
      :unknown  => 0,
      :file     => 1,
      :dir      => 2,
      :char     => 3,
      :block    => 4,
      :fifo     => 5,
      :socket   => 6,
      :sym_link => 7
    }

    ORIGINAL = BinaryStruct.new([
      'L',  'inode_val',  # Inode address of metadata.
      'S',  'entry_len',  # Length of entry.
      'S',  'name_len',   # Length of name.
    ])

    NEW = BinaryStruct.new([
      'L',  'inode_val',  # Inode address of metadata.
      'S',  'entry_len',  # Length of entry.
      'C',  'name_len',   # Length of name.
      'C',  'file_type',  # Type of file
    ])

    ###

    attr_reader :fs, :is_new, :name

    attr_writer :inode, :file_type

    alias :new? :is_new

    def initialize(fs, data, is_new = true)
      @fs = fs
      @is_new = is_new

      raise "nil directory entry data" if data.nil?
      decode!(data)

      raise "invalid file type" unless file_type.nil? || FILE_TYPES.values.include?(file_type)
    end

    private

    def decode!(data)
      @de = new? ? NEW.decode(data[0..NEW.size]) : ORIGINAL.decode(data[0..ORIGINAL.size])

      return unless has_name?
      @name = data[NEW.size, @de['name_len']]
    end

    public

    ###

    def close
    end

    def has_name?
      @has_name ||= @de['name_len'] != 0
    end

    ###

    def inode
      @inode ||= @de['inode_val']
    end

    def len
      @len ||= @de['entry_len']
    end

    alias :size :len

    def file_type
      return nil unless new?
      @file_type ||= @de['file_type']
    end

    ###

    def dir?
      @file_type == FILE_TYPES[:dir]
    end

    def file?
      @file_type == FILE_TYPES[:file]
    end

    def symlink?
      @file_type == FILE_TYPES[:sym_link]
    end

    def atime
      @atime ||= Time.now
    end

    def ctime
      Time.now
    end

    def mtime
      Time.now
    end

    def to_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n"  +
      "Inode   : #{inode}\n"                         +
      "Len     : #{len}\n"                           +
      "Name len: 0x#{'%04x' % @de['name_len']}\n"    +
      (new? ? "Type    : #{file_type.to_s}\n" : "")  +
      "Name    : #{name}\n"
    end

    alias :dump :to_s
  end # class DirectoryEntry
end # module VirtFS::Ext3
