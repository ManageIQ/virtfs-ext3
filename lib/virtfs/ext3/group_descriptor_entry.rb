require 'binary_struct'

module VirtFS::Ext3
  class GroupDescriptorEntry
    STRUCT = BinaryStruct.new([
      'L',  'blk_bmp',        # Starting block address of block bitmap.
      'L',  'inode_bmp',      # Starting block address of inode bitmap.
      'L',  'inode_table',    # Starting block address of inode table.
      'S',  'unalloc_blks',   # Number of unallocated blocks in group.
      'S',  'unalloc_inodes', # Number of unallocated inodes in group.
      'S',  'num_dirs',       # Number of directories in group.
      'a14',  'unused1',      # Unused.
    ])

    attr_accessor :block_alloc_bitmap, :inode_alloc_bitmap

    def initialize(buf)
      raise "nil buffer" if buf.nil?
      @gde = STRUCT.decode(buf)
    end

    def block_bmp
      @block_bmp ||= @gde['blk_bmp']
    end

    def inode_bmp
      @inode_bmp ||= @gde['inode_bmp']
    end

    def inode_table
      @inode_table ||= @gde['inode_table']
    end

    def unalloc_blks
      @unalloc_blks ||= @gde['unalloc_blks']
    end

    def unalloc_inodes
      @unalloc_inodes ||= @gde['unalloc_inodes']
    end

    def num_dirs
      @num_dirs ||= @gde['num_dirs']
    end

    def to_extended_s
      [to_s, "Block allocation\n#{block_alloc_bitmap}",
             "Inode allocation\n#{inode_alloc_bitmap}"].join
    end

    def to_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n"          \
       "Block bitmap      : 0x#{'%08x' % blk_bmp}\n"         \
       "Inode bitmap      : 0x#{'%08x' % inode_bmp}\n"       \
       "Inode table       : 0x#{'%08x' % inode_table}\n"     \
       "Unallocated blocks: 0x#{'%04x' % unalloc_blks}\n"    \
       "Unallocated inodes: 0x#{'%04x' % unalloc_inodes}\n"  \
       "Num directories   : 0x#{'%04x' % num_dirs}\n"
    end

    alias :dump :to_s
  end # class GroupDescriptorEntry
end # module VirtFS::Ext3
