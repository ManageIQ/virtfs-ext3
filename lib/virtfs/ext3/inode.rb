require_relative 'directory_entry'
require 'binary_struct'

module VirtFS::Ext3
  class Inode
    STRUCT = BinaryStruct.new([
      'S',  'file_mode',    # File mode (type and permission), see PF_ DF_ & FM_ below.
      'S',  'uid_lo',       # Lower 16-bits of user id.
      'L',  'size_lo',      # Lower 32-bits of size in bytes.
      'L',  'atime',        # Last access time.
      'L',  'ctime',        # Last change time.
      'L',  'mtime',        # Last modification time.
      'L',  'dtime',        # Time deleted.
      'S',  'gid_lo',       # Lower 16-bits of group id.
      'S',  'link_count',   # Link count.
      'L',  'sector_count', # Sector count.
      'L',  'flags',        # Inode flags, see IF_ below.
      'L',  'unused1',      # Unused.
      'a48',  'blk_ptrs',   # 12 direct block pointers.
      'L',  'ind_ptr',      # 1 single indirect block pointer.
      'L',  'dbl_ind_ptr',  # 1 double indirect block pointer.
      'L',  'tpl_ind_ptr',  # 1 triple indirect block pointer.
      'L',  'gen_num',      # Generation number (NFS).
      'L',  'ext_attrib',   # Extended attribute block (ACL).
      'L',  'size_hi',      # Upper 32-bits of size in bytes or directory ACL.
      'L',  'frag_blk',     # Block address of fragment.
      'C',  'frag_idx',     # Fragment index in block.
      'C',  'frag_siz',     # Fragment size.
      'S',  'unused2',      # Unused.
      'S',  'uid_hi',       # Upper 16-bits of user id.
      'S',  'gid_hi',       # Upper 16-bits of group id.
      'L',  'unused3',      # Unused.
    ])

    # Offset of block pointers for those files whose content is
    # a symbolic link of less than 60 chars.
    SYM_LNK_OFFSET  = 40
    SYM_LNK_SIZE    = 60

    # Bits 0 to 8 of file mode.
    PF_O_EXECUTE  = 0x0001  # owner execute
    PF_O_WRITE    = 0x0002  # owner write
    PF_O_READ     = 0x0004  # owner read
    PF_G_EXECUTE  = 0x0008  # group execute
    PF_G_WRITE    = 0x0010  # group write
    PF_G_READ     = 0x0020  # group read
    PF_U_EXECUTE  = 0x0040  # user execute
    PF_U_WRITE    = 0x0080  # user write
    PF_U_READ     = 0x0100  # user read

    # For accessor convenience.
    MSK_PERM_OWNER = (PF_O_EXECUTE | PF_O_WRITE | PF_O_READ)
    MSK_PERM_GROUP = (PF_G_EXECUTE | PF_G_WRITE | PF_G_READ)
    MSK_PERM_USER  = (PF_U_EXECUTE | PF_U_WRITE | PF_U_READ)

    # Bits 9 to 11 of file mode.
    DF_STICKY     = 0x0200
    DF_SET_GID    = 0x0400
    DF_SET_UID    = 0x0800

    # Bits 12 to 15 of file mode.
    FM_FIFO       = 0x1000  # fifo device (pipe)
    FM_CHAR       = 0x2000  # char device
    FM_DIRECTORY  = 0x4000  # directory
    FM_BLOCK_DEV  = 0x6000  # block device
    FM_FILE       = 0x8000  # regular file
    FM_SYM_LNK    = 0xa000  # symbolic link
    FM_SOCKET     = 0xc000  # socket device

    # For accessor convenience.
    MSK_FILE_MODE = 0xf000
    MSK_IS_DEV    = (FM_FIFO | FM_CHAR | FM_BLOCK_DEV | FM_SOCKET)

    # Inode flags.
    IF_SECURE_DEL = 0x00000001  # wipe when deleting
    IF_KEEP_COPY  = 0x00000002  # never delete
    IF_COMPRESS   = 0x00000004  # compress content
    IF_SYNCHRO    = 0x00000008  # don't cache
    IF_IMMUTABLE  = 0x00000010  # file cannot change
    IF_APPEND     = 0x00000020  # always append
    IF_NO_DUMP    = 0x00000040  # don't cat
    IF_NO_ATIME   = 0x00000080  # don't update atime
    IF_HASH_INDEX = 0x00001000  # if dir, has hash index
    IF_JOURNAL    = 0x00002000  # if using journal, is journal inode

    # Lookup table for File Mode to File Type.
    FM2FT = {
      Inode::FM_FIFO      => DirectoryEntry::FILE_TYPES[:fifo],
      Inode::FM_CHAR      => DirectoryEntry::FILE_TYPES[:char],
      Inode::FM_DIRECTORY => DirectoryEntry::FILE_TYPES[:dir],
      Inode::FM_BLOCK_DEV => DirectoryEntry::FILE_TYPES[:block],
      Inode::FM_FILE      => DirectoryEntry::FILE_TYPES[:file],
      Inode::FM_SYM_LNK   => DirectoryEntry::FILE_TYPES[:sym_link],
      Inode::FM_SOCKET    => DirectoryEntry::FILE_TYPES[:socket]
    }

    attr_reader :symlnk

    def initialize(buf)
      raise "nil buffer" if buf.nil?
      @in = STRUCT.decode(buf)

      # If this is a symlnk < 60 bytes, grab the link metadata.
      process_symlink(buf) if symlink? && length < SYM_LNK_SIZE
    end

    private

    def process_symlink(buf)
      @symlnk = buf[SYM_LNK_OFFSET, SYM_LNK_SIZE]
      # rPath is a wildcard. Sometimes they allocate when length < SYM_LNK_SIZE.
      # Analyze each byte of the first block pointer & see if it makes sense as ASCII.
      @symlnk[0, 4].each_byte do |c|
        if !(c > 45 && c < 48) && !((c > 64 && c < 91) || (c > 96 && c < 123))
          # This seems to be a block pointer, so nix @symlnk & pretend it's a regular file.
          @symlnk = nil
          break
        end
      end
    end

    public

    def mode
      @mode ||= @in['file_mode']
    end

    def flags
      @flags ||= @in['flags']
    end

    def length
      @length ||= begin
        l  =  @in['size_lo']
        l += (@in['size_hi'] << 32) unless dir?
        l
      end
    end

    def block_pointers
      @block_pointers ||= @in['blk_ptrs'].unpack('L12')
    end

    def single_indirect_block_pointer
      @single_indirect_block_pointer ||= @in['ind_ptr']
    end

    def double_indirect_block_pointer
      @double_indirect_block_pointer ||= @in['dbl_ind_ptr']
    end

    def triple_indirect_block_pointer
      @triple_indirect_block_pointer ||= @in['tpl_ind_ptr']
    end

    def uid
      (@in['uid_hi'] << 16) | @in['uid_lo']
    end

    def dir?
      @mode & FM_DIRECTORY == FM_DIRECTORY
    end

    def file?
      @mode & FM_FILE == FM_FILE
    end

    def dev?
      @mode & MSK_IS_DEV > 0
    end

    def symlink?
      @mode & FM_SYM_LNK == FM_SYM_LNK
    end

    def atime
      @atime ||= Time.at(@in['atime'])
    end

    def ctime
      @ctime ||= Time.at(@in['ctime'])
    end

    def mtime
      @mtime ||= Time.at(@in['mtime'])
    end

    def dtime
      @dtime ||= Time.at(@in['dtime'])
    end

    def gid
      (@in['gid_hi'] << 16) | @in['gid_lo']
    end

    def permissions
      @in['file_mode'] & (MSK_PERM_OWNER | MSK_PERM_GROUP | MSK_PERM_USER)
    end

    def owner_permissions
      @in['file_mode'] & MSK_PERM_OWNER
    end

    def group_permissions
      @in['file_mode'] & MSK_PERM_GROUP
    end

    def user_permissions
      @in['file_mode'] & MSK_PERM_USER
    end

    def file_mode_file_type
      FM2FT[@mode & MSK_FILE_MODE]
    end

    def direct_block_string
      12.times.collect { |i| "  #{i} = 0x#{'%08x' % @block_pointers[i] }\n" }.join
    end

    def gen_num
      @gen_num ||= @in['gen_num']
    end

    def ext_attrib
      @ext_attrib ||= @in['ext_attrib']
    end

    def frag_blk
      @frag_blk ||= @in['frag_blk']
    end

    def frag_idx
      @frag_idx ||= @in['frag_idx']
    end

    def frag_size
      @frag_size ||= @in['frag_siz']
    end

    def to_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n"              +
      "File mode    : 0x#{'%04x' % @in['file_mode']}\n"          +
      "UID          : #{uid}\n"                                  +
      "Size         : #{length}\n"                               +
      "ATime        : #{aTime}\n"                                +
      "CTime        : #{cTime}\n"                                +
      "MTime        : #{mTime}\n"                                +
      "DTime        : #{dTime}\n"                                +
      "GID          : #{gid}\n"                                  +
      "Link count   : #{@in['link_count']}\n"                    +
      "Sector count : #{@in['sector_count']}\n"                  +
      "Flags        : 0x#{'%08x' % @in['flags']}\n"              +
      "Direct block pointers:\n"                                 +
       direct_block_string                                       +

      "Sng Indirect : 0x#{'%08x' % single_indirect_block_ptr}\n" +
      "Dbl Indirect : 0x#{'%08x' % double_indirect_block_ptr}\n" +
      "Tpl Indirect : 0x#{'%08x' % triple_indirect_block_ptr}\n" +
      "Generation   : 0x#{'%08x' % gen_num}\n"                   +
      "Ext attrib   : 0x#{'%08x' % ext_attrib}\n"                +
      "Frag blk adrs: 0x#{'%08x' % frag_blk}\n"                  +
      "Frag index   : 0x#{'%02x' % frag_idx}\n"                  +
      "Frag size    : 0x#{'%02x' % frag_siz}\n"
   end

   alias :dump :to_s
  end # class Inode
end # module VirtFS::Ext3
