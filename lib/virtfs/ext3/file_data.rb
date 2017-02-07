require 'memory_buffer'

require_relative 'block_pointers_path'

module VirtFS::Ext3
  class FileData
    SIZEOF_LONG           = 4
    MAX_READ              = 4294967296
    DEFAULT_BLOCK_SIZE    = 1024

    attr_reader :pos

    # Initialization
    def initialize(inode, superblock)
      raise "nil inode "     if inode.nil?
      raise "nil superblock" if superblock.nil?

      @sb         = superblock
      @inode      = inode
      @block_size = @sb.block_size
      @path       = BlockPointersPath.new(@block_size / SIZEOF_LONG)

      rewind
    end

    def rewind
      @pos = 0
    end

    def seek(offset, method = IO::SEEK_SET)
      @pos = case method
             when IO::SEEK_SET then offset
             when IO::SEEK_CUR then @pos + offset
             when IO::SEEK_END then @inode.length - offset
             end

      @pos = 0             if @pos < 0
      @pos = @inode.length if @pos > @inode.length
      @pos
    end

    def read(bytes = @inode.length)
      raise "can't read 4GB+ at a time" if bytes >= MAX_READ
      return nil if @pos >= @inode.length

      # Handle symbolic links.
      return read_symlink(@pos, bytes) if @inode.symlnk

      bytes = @inode.length - @pos if @pos + bytes > @inode.length
      read_block(@pos, bytes)
    end

    def write(buf, _len = buf.length)
      raise "writes not supported"
    end

    private

    def read_symlink(pos, bytes)
      out   = @inode.symlnk[@pos...bytes]
      @pos += bytes
      out
    end

    def read_block(pos, bytes)
      sblock, sbyte, eblock, ebyte, nblocks = block_info(@pos, bytes)
      out   = blocks(sblock, nblocks)
      @pos += bytes
      out[sbyte, bytes]
    end


    def block_info(pos, len)
      sblock, sbyte = pos.divmod(@block_size)
      eblock, ebyte = (pos + len - 1).divmod(@block_size)
            nblocks = eblock - sblock + 1
      return sblock, sbyte, eblock, ebyte, nblocks
    end

    def blocks(sblock, nblocks = 1)
      @path.block = sblock
      out = MemoryBuffer.create(nblocks * @block_size)
      nblocks.times do |i|
        out[i * @block_size, @block_size] = block(@path)
        @path.succ!
      end
      out
    end

    def block_pointer(path)
      case path.index_type
      when :direct
        @inode.block_pointers[path.direct_index]
      when :single_indirect
        p = single_indirect_pointers(@inode.single_indirect_block_pointer)
        p[path.single_indirect_index]
      when :double_indirect
        p = double_indirect_pointers(@inode.double_indirect_block_pointer)
        p = single_indirect_pointers(p[path.single_indirect_index])
        p[path.double_indirect_index]
      when :triple_indirect
        # FIXME: is this right?
        p = triple_indirect_pointers(@inode.double_indirect_block_pointer)
        p = double_indirect_pointers(p[path.single_indirect_index])
        p = single_indirect_pointers(p[path.double_indirect_index])
        p[path.triple_indirect_index]
      end
    end

    def block(path)
      @sb.block(block_pointer(path))
    end

    def single_indirect_pointers(block)
      return @single_indirect_pointers if block == @single_indirect_block
      @single_indirect_block    = block
      @single_indirect_pointers = block_pointers(block)
    end

    def double_indirect_pointers(block)
      return @double_indirect_pointers if block == @double_indirect_block
      @double_indirect_block    = block
      @double_indirect_pointers = block_pointers(block)
    end

    def triple_indirect_pointers(block)
      return @triple_indirect_block if block == @triple_indirect_block
      @triple_indirect_block    = block
      @triple_indirect_pointers = block_pointers(block)
    end

    def block_pointers(block)
      @sb.block(block).unpack('L*')
    end
  end # class FileData
end # module VirtFS::Ext3
