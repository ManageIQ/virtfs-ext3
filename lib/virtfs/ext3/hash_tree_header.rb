module VirtFS::Ext3
  class HashTreeHeader
    HEADER = [
      'L',  'unused1',    # Unused.
      'C',  'hash_ver',   # Hash version.
      'C',  'length',     # Length of this structure.
      'C',  'leaf_level', # Levels of leaves.
      'C',  'unused2',    # Unused.
    ]

    def initialize(buf)
      raise "nil buffer" if buf.nil?
      @hth = HASH_TREE_HEADER.decode(buf)
    end

    def hash_version
      @hash_version ||= @hth['hash_ver']
    end

    def length
      @length ||= @hth['length']
    end

    def leaf_level
      @leaf_level ||= @hth['leaf_level']
    end
  end # class HashTreeHeader
end # module VirtFS::Ext3
