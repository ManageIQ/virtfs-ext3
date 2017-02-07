require_relative 'group_descriptor_entry'
require_relative 'alloc_bitmap'
require 'binary_struct'

module VirtFS::Ext3
  class GroupDescriptorTable
    def initialize(sb)
      raise "nil superblock" if sb.nil?
      read_all(sb)
    end

    public

    def each
      @gdt.each { |gde| yield(gde) }
    end

    def [](group)
      @gdt[group]
    end

     def to_extended_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n" +
      @gdt.collect { |gde| gde.to_extended_s }.join
     end

    def to_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n" +
      @gdt.collect { |gde| gde.to_s }.join
    end

    def dump(dump_bitmaps = false)
      dump_bitmaps ? to_extended_s : to_s
    end

    private

    def read_all(sb)
      # Read all the group descriptor entries.
      @gdt = []
      sb.stream.seek(sb.block_to_address(sb.block_size == 1024 ? 2 : 1))
      buf = sb.stream.read(GroupDescriptorEntry::STRUCT.size * sb.num_groups)
      offset = 0
      sb.num_groups.times do
        gde = GroupDescriptorEntry.new(buf[offset, GroupDescriptorEntry::STRUCT.size])

        # Construct allocation bitmaps for blocks & inodes.
        gde.block_alloc_bitmap = alloc_bitmap(sb, gde.block_bmp, sb.block_size)
        gde.inode_alloc_bitmap = alloc_bitmap(sb, gde.inode_bmp, sb.inodes_per_group / 8)

        @gdt << gde

        offset += GroupDescriptorEntry::STRUCT.size
      end
    end

    def alloc_bitmap(sb, block, size)
      sb.stream.seek(sb.block_to_address(block))
      AllocBitmap.new(sb.stream.read(size))
    end
  end # class GroupDescriptorTable
end # module VirtFS::Ext3
