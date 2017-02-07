# encoding: US-ASCII

require_relative 'group_descriptor_table'
require_relative 'inode'

require 'binary_struct'
require 'virt_disk/disk_uuid'
require 'stringio'
require 'memory_buffer'

require 'rufus/lru'

module VirtFS::Ext3
  class Superblock
    SUPERBLOCK = BinaryStruct.new([
      'L',  'num_inodes',         # Number of inodes in file system.
      'L',  'num_blocks',         # Number of blocks in file system.
      'L',  'reserved_blocks',    # Number of reserved blocks to prevent file system from filling up.
      'L',  'unallocated_blocks', # Number of unallocated blocks.
      'L',  'unallocated_inodes', # Number of unallocated inodes.
      'L',  'block_group_zero',   # Block where block group 0 starts.
      'L',  'block_size',         # Block size (saved as num bits to shift 1024 left).
      'L',  'fragment_size',      # Fragment size (saved as num bits to shift 1024 left).
      'L',  'blocks_in_group',    # Number of blocks in each block group.
      'L',  'fragments_in_group', # Number of fragments in each block group.
      'L',  'inodes_in_group',    # Number of inodes in each block group.
      'L',  'last_mount_time',    # Time FS was last mounted.
      'L',  'last_write_time',    # Time FS was last written to.
      'S',  'mount_count',        # Current mount count.
      'S',  'max_mount_count',    # Maximum mount count.
      'S',  'signature',          # Always 0xef53
      'S',  'fs_state',           # File System State: see FSS_ below.
      'S',  'err_method',         # Error Handling Method: see EHM_ below.
      'S',  'ver_minor',          # Minor version number.
      'L',  'last_check_time',    # Last consistency check time.
      'L',  'forced_check_int',   # Forced check interval.
      'L',  'creator_os',         # Creator OS: see CO_ below.
      'L',  'ver_major',          # Major version: see MV_ below.
      'S',  'uid_res_blocks',     # UID that can use reserved blocks.
      'S',  'gid_res_blocks',     # GID that can uss reserved blocks.
      # Begin dynamic version fields
      'L',  'first_inode',        # First non-reserved inode in file system.
      'S',  'inode_size',         # Size of each inode.
      'S',  'block_group',        # Block group that this superblock is part of (if backup copy).
      'L',  'compat_flags',       # Compatible feature flags (see CFF_ below).
      'L',  'incompat_flags',     # Incompatible feature flags (see ICF_ below).
      'L',  'ro_flags',           # Read Only feature flags (see ROF_ below).
      'a16',  'fs_id',            # File system ID (UUID or GUID).
      'a16',  'vol_name',         # Volume name.
      'a64',  'last_mnt_path',    # Path where last mounted.
      'L',  'algo_use_bmp',       # Algorithm usage bitmap.
      # Performance hints
      'C',  'file_prealloc_blks', # Blocks to preallocate for files.
      'C',  'dir_prealloc_blks',  # Blocks to preallocate for directories.
      'S',  'unused1',            # Unused.
      # Journal support
      'a16',  'jrnl_id',          # Joural ID (UUID or GUID).
      'L',  'jrnl_inode',         # Journal inode.
      'L',  'jrnl_device',        # Journal device.
      'L',  'orphan_head',        # Head of orphan inode list.
      'a16',  'hash_seed',        # HTREE hash seed. This is actually L4 (__u32 s_hash_seed[4])
      'C',  'hash_ver',           # Default hash version.
      'C',  'unused2',
      'S',  'unused3',
      'L',  'mount_opts',         # Default mount options.
      'L',  'first_meta_blk_grp', # First metablock block group.
      'a360', 'reserved'          # Unused.
    ])
  
    SUPERBLOCK_SIG    = 0xef53
    SUPERBLOCK_OFFSET = 1024
    SUPERBLOCK_SIZE   = 1024
    GDE_SIZE          = 32
    INODE_SIZE        = 128       # Default inode size.
  
    # Simpler structure for just validating the presence of a superblock
    SUPERBLOCK_VALIDATE = BinaryStruct.new([
      'x56', nil,
      'S',  'signature',          # Always 0xef53
      'S',  'fs_state',           # File System State: see FSS_ below.
      'S',  'err_method',         # Error Handling Method: see EHM_ below.
    ])
    SUPERBLOCK_VALIDATE_SIZE = SUPERBLOCK_VALIDATE.size

    # Default cache sizes.
    DEF_BLOCK_CACHE_SIZE = 50
    DEF_INODE_CACHE_SIZE = 50

    # File System State.
    FSS_CLEAN       = 0x0001  # File system is clean.
    FSS_ERR         = 0x0002  # File system has errors.
    FSS_ORPHAN_REC  = 0x0004  # Orphan inodes are being recovered.
    # NOTE: Recovered NOT by this software but by the 'NIX kernel.
    # IOW start the VM to repair it.
    FSS_END         = FSS_CLEAN | FSS_ERR | FSS_ORPHAN_REC

    # Error Handling Method.
    EHM_CONTINUE    = 1 # No action.
    EHM_RO_REMOUNT  = 2 # Remount file system as read only.
    EHM_PANIC       = 3 # Don't mount? halt? - don't know what this means.

    # Creator OS.
    CO_LINUX    = 0 # NOTE: FS creation tools allow setting this value.
    CO_GNU_HURD = 1 # These values are supposedly defined.
    CO_MASIX    = 2
    CO_FREE_BSD = 3
    CO_LITES    = 4

    # Major Version.
    MV_ORIGINAL = 0 # NOTE: If version is not dynamic, then values from
    MV_DYNAMIC  = 1 # first_inode on may not be accurate.

    # Compatible Feature Flags.
    CFF_PREALLOC_DIR_BLKS = 0x0001  # Preallocate directory blocks to reduce fragmentation.
    CFF_AFS_SERVER_INODES = 0x0002  # AFS server inodes exist in system.
    CFF_JOURNAL           = 0x0004  # File system has journal (Ext3).
    CFF_EXTENDED_ATTRIBS  = 0x0008  # Inodes have extended attributes.
    CFF_BIG_PART          = 0x0010  # File system can resize itself for larger partitions.
    CFF_HASH_INDEX        = 0x0020  # Directories use hash index (another modified b-tree).
    CFF_FLAGS             = (CFF_PREALLOC_DIR_BLKS |
                             CFF_AFS_SERVER_INODES |
                             CFF_JOURNAL           |
                             CFF_EXTENDED_ATTRIBS  |
                             CFF_BIG_PART          |
                             CFF_HASH_INDEX)

    # Incompatible Feature flags.
    ICF_COMPRESSION       = 0x0001  # Not supported on Linux?
    ICF_FILE_TYPE         = 0x0002  # Directory entries contain file type field.
    ICF_RECOVER_FS        = 0x0004  # File system needs recovery.
    ICF_JOURNAL           = 0x0008  # File system uses journal device.
    ICF_META_BG           = 0x0010  #
    ICF_EXTENTS           = 0x0040  # File system uses extents (ext4)
    ICF_64BIT             = 0x0080  # File system uses 64-bit
    ICF_MMP               = 0x0100  #
    ICF_FLEX_BG           = 0x0200  #
    ICF_EA_INODE          = 0x0400  # EA in inode
    ICF_DIRDATA           = 0x1000  # data in dirent
    ICF_FLAGS             = (ICF_COMPRESSION |
                             ICF_FILE_TYPE   |
                             ICF_RECOVER_FS  |
                             ICF_JOURNAL     |
                             ICF_META_BG     |
                             ICF_EXTENTS     |
                             ICF_64BIT       |
                             ICF_MMP         |
                             ICF_FLEX_BG     |
                             ICF_EA_INODE    |
                             ICF_DIRDATA)

    # ReadOnly Feature flags.
    ROF_SPARSE            = 0x0001  # Sparse superblocks & group descriptor tables.
    ROF_LARGE_FILES       = 0x0002  # File system contains large files (over 4G).
    ROF_BTREES            = 0x0004  # Directories use B-Trees (not implemented?).
    ROF_FLAGS             = (ROF_SPARSE | ROF_LARGE_FILES | ROF_BTREES)

    attr_reader :num_groups, :fsId, :stream, :fsId, :volName

    @@track_inodes = false

    def self.superblock?(buf)
      sb = SUPERBLOCK_VALIDATE.decode(buf)
      sb['signature']  == SUPERBLOCK_SIG &&
      sb['fs_state']   <= FSS_END        &&
      sb['err_method'] <= EHM_PANIC
    end

    def ext4?
      false
    end

    def initialize(stream)
      raise "nil stream" if stream.nil?
      @stream = stream

      # Seek, read & decode the superblock structure
      @stream.seek(SUPERBLOCK_OFFSET)
      @sb = SUPERBLOCK.decode(@stream.read(SUPERBLOCK_SIZE))

      @block_cache = LruHash.new(DEF_BLOCK_CACHE_SIZE)
      @inode_cache = LruHash.new(DEF_INODE_CACHE_SIZE)

      validate!
      preprocess!
    end

    private

    def validate!
      # Grab some quick facts & make sure there's nothing wrong. Tight qualification.
      raise "Invalid signature=[#{signature}]"                     if signature  != SUPERBLOCK_SIG
      raise "Invalid file system state"                            if fs_state    > FSS_END
      raise "Invalid error handling method=[#{@sb['err_method']}]" if err_method  > EHM_PANIC
      raise "Filesystem has extents (ext4)"                        if has_extents?
    end

    def preprocess!
      @sb['vol_name'].delete!("\000")
      @sb['last_mnt_path'].delete!("\000")
      @num_groups, @last_group_blocks = @sb['num_blocks'].divmod(@sb['blocks_in_group'])

      @num_groups += 1 if @last_group_blocks > 0
      @fsId        = DiskUUID.parse_raw(@sb['fs_id'])
      @volName     = @sb['vol_name']
      @jrnlId      = DiskUUID.parse_raw(@sb['jrnl_id'])
    end

    public

    def block_size
      @block_size  ||= 1024 << @sb['block_size']
    end

    def has_extents?
      bit?(@sb['incompat_flags'], ICF_EXTENTS)
    end

    def signature
      @signature ||= @sb['signature']
    end

    def fs_state
      @fs_state ||= @sb['fs_state']
    end

    def err_method
      @err_method ||= @sb['err_method']
    end

    def gdt
      @gdt ||= GroupDescriptorTable.new(self)
    end

    def dynamic?
      @sb['ver_major'] == MV_DYNAMIC
    end

    def new_dir_entry?
      bit?(@sb['incompat_flags'], ICF_FILE_TYPE)
    end

    def fragment_size
      @fragment_size ||= 1024 << @sb['fragment_size']
    end

    def blocks_per_group
      @sb['blocks_in_group']
    end

    def fragments_per_group
      @sb['fragments_in_group']
    end

    def inodes_per_group
      @sb['inodes_in_group']
    end

    def inode_size
      dynamic? ? @sb['inode_size'] : INODE_SIZE
    end

    def free_bytes
      @sb['unallocated_blocks'] * @block_size
    end

    def block_num_to_group_num(blk)
      raise "block is nil" if blk.nil?
      group  = (blk - @sb['block_group_zero']) / @sb['blocks_in_group']
      offset = blk.modulo(@sb['blocks_in_group'])
      return group, offset
    end

    def first_group_block_num(group)
      group * @sb['blocks_in_group'] + @sb['block_group_zero']
    end

    def inode_num_to_group_num(inode)
      (inode - 1).divmod(inodes_per_group)
    end

    def block_to_address(blk)
      address  = blk * @block_size
      address += (SUPERBLOCK_SIZE + GDE_SIZE * @num_groups)  if address == SUPERBLOCK_OFFSET
      address
    end

    def valid_inode?(inode)
      group, offset = inode_num_to_group_num(inode)
      gde = gdt[group]
      gde.inode_alloc_bmp[offset]
    end

    def valid_block?(blk)
      group, offset = block_num_to_group_num(blk)
      gde = gdt[group]
      gde.block_alloc_bmp[offset]
    end

    # Ignore allocation is for testing only.
    def get_inode(inode, _ignore_alloc = false)
      return @inode_cache[inode] if @inode_cache.key?(inode)
      group, offset = inode_num_to_group_num(inode)
      gde = gdt[group]
      # raise "Inode #{inode} is not allocated" if (not gde.inode_alloc_bmp[offset] and not ignore_alloc)
      @stream.seek(block_to_address(gde.inode_table) + offset * inode_size)
      @inode_cache[inode] = Inode.new(@stream.read(inode_size))
    end

    # Ignore allocation is for testing only.
    def block(blk, _ignore_alloc = false)
      raise "block is nil" if blk.nil?
      return @block_cache[blk] if @block_cache.key?(blk)

      if blk == 0
        @block_cache[blk] = MemoryBuffer.create(@block_size)

      else
        group, offset = block_num_to_group_num(blk)
        gde = gdt[group]

        address = block_to_address(blk)  # This function will read the block into our cache

        @stream.seek(address)
        @block_cache[blk] = @stream.read(@block_size)
      end
    end

    private

    def bit?(field, bit)
      field & bit == bit
    end

    def dynamic_str
      "First non-res inode   : #{@sb['first_inode']}\n"               \
      "Size of inode         : #{@sb['inode_size']}\n"                \
      "Block group of this SB: #{@sb['block_group']}\n"               \
      "Compatible features   : 0x#{'%08x' % @sb['compat_flags']}\n"   \
      "Incompatible features : 0x#{'%08x' % @sb['incompat_flags']}\n" \
      "Read Only features    : 0x#{'%08x' % @sb['ro_flags']}\n"       \
      "File system id        : #{@fsId}\n"                            \
      "Volume name           : #{@sb['vol_name']}\n"                  \
      "Last mount path       : #{@sb['last_mnt_path']}\n"             \
      "Algorithm usage bitmap: 0x#{'%08x' % @sb['algo_use_bmp']}\n"   \
      "Blocks prealloc files : #{@sb['file_prealloc_blks']}\n"        \
      "Blocks prealloc dirs  : #{@sb['dir_prealloc_blks']}\n"         \
      "Journal id            : #{@jrnlId}\n"                          \
      "Journal inode         : #{@sb['jrnl_inode']}\n"                \
      "Journal device        : #{@sb['jrnl_device']}\n"               \
      "Orphan inode head     : #{@sb['orphan_head']}\n"
    end

    def compat_features_str
      cff = @sb['compat_flags']
      extra_cff = cff - (cff & CFF_FLAGS)

      "Compatible Feature Flags:\n"                                                     +
      (bit?(cff, CFF_PREALLOC_DIR_BLKS) ?  "  CFF_PREALLOC_DIR_BLKS\n"            : "") +
      (bit?(cff, CFF_AFS_SERVER_INODES) ?  "  CFF_AFS_SERVER_INODE\n"             : "") +
      (bit?(cff, CFF_JOURNAL)           ?  "  CFF_JOURNAL\n"                      : "") +
      (bit?(cff, CFF_EXTENDED_ATTRIBS)  ?  "  CFF_EXTENDED_ATTRIBS\n"             : "") +
      (bit?(cff, CFF_BIG_PART)          ?  "  CFF_BIG_PART\n"                     : "") +
      (bit?(cff, CFF_HASH_INDEX)        ?  "  CFF_HASH_INDEX\n"                   : "") +
      (extra_cff != 0                   ? ("  Extra Flags: 0x%08X\n" % extra_cff) : "")
    end

    def incompat_features_str
      icf = @sb['incompat_flags']
      extra_icf = icf - (icf & ICF_FLAGS)

      "Incompatible Feature Flags:\n"                                             +
      (bit?(icf, ICF_COMPRESSION) ?  "  ICF_COMPRESSION\n"                  : "") +
      (bit?(icf, ICF_FILE_TYPE)   ?  "  ICF_FILE_TYPE\n"                    : "") +
      (bit?(icf, ICF_RECOVER_FS)  ?  "  ICF_RECOVER_FS\n"                   : "") +
      (bit?(icf, ICF_JOURNAL)     ?  "  ICF_JOURNAL\n"                      : "") +
      (bit?(icf, ICF_META_BG)     ?  "  ICF_META_BG\n"                      : "") +
      (bit?(icf, ICF_EXTENTS)     ?  "  ICF_EXTENTS\n"                      : "") +
      (bit?(icf, ICF_64BIT)       ?  "  ICF_64BIT\n"                        : "") +
      (bit?(icf, ICF_MMP)         ?  "  ICF_MMP\n"                          : "") +
      (bit?(icf, ICF_FLEX_BG)     ?  "  ICF_FLEX_BG\n"                      : "") +
      (bit?(icf, ICF_EA_INODE)    ?  "  ICF_EA_INODE\n"                     : "") +
      (bit?(icf, ICF_DIRDATA)     ?  "  ICF_DIRDATA\n"                      : "") +
      (extra_icf != 0             ? ("  Extra Flags: 0x%08X\n" % extra_icf) : "")
    end

    # read only features
    def ro_features_str
      rof = @sb['ro_flags']
      extra_rof = rof - (rof & ROF_FLAGS)

      "Read Only Feature Flags:\n"                                                +
      (bit?(rof, ROF_SPARSE)      ?  "  ROF_SPARSE\n"                       : "") +
      (bit?(rof, ROF_LARGE_FILES) ?  "  ROF_LARGE_FILES\n"                  : "") +
      (bit?(rof, ROF_BTREES)      ?  "  ROF_BTREES\n"                       : "") +
      (extra_rof != 0             ? ("  Extra Flags: 0x%08X\n" % extra_rof) : "")
    end

    def features_str
        compat_features_str +
      incompat_features_str +
            ro_features_str
    end

    public

    def to_s
      "\#<#{self.class}:0x#{'%08x' % object_id}>\n"                                                           +
      "Number of inodes      : #{@sb['num_inodes']}\n"                                                        +
      "Number of blocks      : #{@sb['num_blocks']}\n"                                                        +
      "Reserved blocks       : #{@sb['reserved_blocks']}\n"                                                   +
      "Unallocated blocks    : #{@sb['unallocated_blocks']}\n"                                                +
      "Unallocated inodes    : #{@sb['unallocated_inodes']}\n"                                                +
      "Block group 0         : #{@sb['block_group_zero']}\n"                                                  +
      "Block size            : #{@sb['block_size']} (#{@blockSize} bytes)\n"                                  +
      "Fragment size         : #{@sb['fragment_size']} (#{fragmentSize} bytes)\n"                             +
      "Blocks per group      : #{@sb['blocks_in_group']} (#{blocksPerGroup} blocks per group)\n"              +
      "Fragments per group   : #{@sb['fragments_in_group']} (#{fragmentsPerGroup} fragments per group)\n"     +
      "Inodes per group      : #{@sb['inodes_in_group']} (#{inodesPerGroup} inodes per group)\n"              +
      "Last mount time       : #{Time.at(@sb['last_mount_time'])}\n"                                          +
      "Last write time       : #{Time.at(@sb['last_write_time'])}\n"                                          +
      "Current mount count   : #{@sb['mount_count']}\n"                                                       +
      "Maximum mount count   : #{@sb['max_mount_count']}\n"                                                   +
      "Signature             : #{@sb['signature']}\n"                                                         +
      "File system state     : #{@sb['fs_state']}\n"                                                          +
      "Error hndling methd   : #{@sb['err_method']}\n"                                                        +
      "Minor version         : #{@sb['ver_minor']}\n"                                                         +
      "Last consistency check: #{Time.at(@sb['last_check_time'])}\n"                                          +
      "Forced check interval : #{@sb['forced_check_int']} sec\n"                                              +
      "Creator OS            : #{@sb['creator_os']}\n"                                                        +
      "Major version         : #{@sb['ver_major']}\n"                                                         +
      "UID can use res blocks: #{@sb['uid_res_blocks']}\n"                                                    +
      "GID can use res blocks: #{@sb['gid_res_blocks']}\n"                                                    +

      (dynamic? ? dynamic_str : "")                                                                           +

      "Number of groups      : #{numGroups}\n"                                                                +
      "Free bytes            : #{freeBytes}\n"                                                                +
      features_str
    end

    alias :dump :to_s

  end # class SuperBlock
end # module VirtFS::Ext3
