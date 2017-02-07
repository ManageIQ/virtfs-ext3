module VirtFS::Ext3
  class HashTreeEntry
    FIRST = [
      'S',  'max_descriptors',  # Maximum number of node descriptors.
      'S',  'cur_descriptors',  # Current number of node descriptors.
      'L',  'first_node',       # Block address of first node.
    ]

    NEXT = [
      'L',  'min_hash',   # Minimum hash value in node.
      'L',  'next_node',  # Block address of next node.
    ]

    def initialize(buf, first = false)
      raise "nil buffer" if buf.nil?

      @first = first
      @hte   = first? ? FIRST.decode(buf) :
                         NEXT.decode(buf)
    end

    def first?
      @first
    end

    def max_descriptors
      @max_descriptors ||= @hte['max_descriptors']
    end

    def current_descriptors
      @current_descriptors ||= @hte['current_descriptors']
    end

    def node
      @node ||= first? ? @hte['first_node'] : @hte['last_node']
    end

    def min_hash
      @min_hash ||= @hte['min_hash']
    end
  end # class HashTreeEntry
end # module VirtFS::Ext3
