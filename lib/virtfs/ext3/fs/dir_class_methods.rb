require 'active_support/core_ext/object/try' # until we can use the safe nav operator

module VirtFS::Ext3
  class FS
    module DirClassMethods
      def dir_delete(p)
        raise "writes not supported"
      end

      def dir_entries(p)
        dir = get_dir(p)
        return nil if dir.nil?
        dir.glob_names
      end

      def dir_exist?(p)
        begin
          !get_dir(p).nil?
        rescue
          false
        end
      end

      def dir_foreach(p, &block)
        r = get_dir(p).try(:glob_names).try(:each, &block)
        block.nil? ? r : nil
      end

      def dir_mkdir(p, permissions)
        raise "writes not supported"
      end

      def dir_new(fs_rel_path, hash_args, _open_path, _cwd)
        get_dir(fs_rel_path)
      end

      private

      def get_dir(p)
        p = unnormalize_path(p)

        # Get an array of directory names, kill off the first (it's always empty).
        names = p.split(/[\\\/]/)
        names.shift

        dir = get_dir_r(names)
        raise "Directory '#{p}' not found" if dir.nil?
        dir
      end

      def get_dir_r(names)
        return root_dir if names.empty?

        # Check for this path in the cache.
        fname = names.join('/')
        if dir_cache.key?(fname)
          #cache_hits += 1
          return dir_cache[fname]
        end

        name = names.pop
        pdir = get_dir_r(names)
        return nil if pdir.nil?

        de = pdir.find_entry(name, DirectoryEntry::FILE_TYPES[:directory])
        return nil if de.nil?
        entry_cache[fname] = de

        dir = Directory.new(self, superblock, de.inode)
        return nil if dir.nil?

        dir_cache[fname] = dir
      end
    end # module DirClassMethods
  end # class FS
end # module VirtFS::Ext3
