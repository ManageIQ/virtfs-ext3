module VirtFS::Ext3
  class AllocBitmap
    def initialize(data)
      raise "nil data" if data.nil?
      @data = data
    end

    def allocated?(number)
      get_status(number)
    end

    def [](number)
      get_status(number)
    end

    def dump
      @data.hex_dump
    end

    private

    def get_status(number)
      byte, mask = index(number)
      @data[byte] & mask == mask
    end

    def index(number)
      byte, bit = number.divmod(8)
      if byte > @data.size - 1
        msg = "AllocBitmap#index: "
        msg += "byte index #{byte} is out of range for data[0:#{@data.size - 1}]"
        raise msg
      end
      mask = 128 >> bit
      return byte, mask
    end
  end # class AllocBitmap
end # module VirtFS::Ext3
