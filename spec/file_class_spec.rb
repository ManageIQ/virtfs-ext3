require 'spec_helper'

describe "Ext3::File class methods" do
  def cassette_path
    "spec/cassettes/file_class.yml"
  end

  before(:each) do
    @full_path   = "/#{@root}/d1/s3"
    @parent_path = "/#{@root}/d1"
    @rel_path    = 's3'
    @full_path2  = "/#{@root}/fA"
  end

  describe ".atime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.atime("nonexistent_file")
      end.to raise_error(/No such file or directory/)
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.atime('/')).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.atime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".basename" do
    it "should return the same value as the standard File.basename" do
      expect(VirtFS::VFile.basename(@full_path)).to eq(VfsRealFile.basename(@full_path))
    end
  end

  describe ".chmod" do
    it "should raise error" do
      expect do
        VirtFS::VFile.chmod(0755, "/mnt/anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".chown" do
    it "should raise error" do
      expect do
        VirtFS::VFile.chown(1, 2, "/mnt/anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".ctime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.ctime("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.ctime(@full_path)).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.ctime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".delete" do
    it "should raise error" do
      expect do
        VirtFS::VFile.delete("/mnt/anything")
      end.to raise_error("writes not supported");
    end
  end

  describe ".directory?" do
    it "should return false when given a nonexistent directory" do
      expect(VirtFS::VFile.directory?("nonexistent_directory")).to be false
    end

    it "should return false when given a regular file" do
      expect(VirtFS::VFile.directory?(@full_path2)).to be false
    end

    it "should return true when given a directory" do
      expect(VirtFS::VFile.directory?(@parent_path)).to be true
    end
  end

  describe ".exist?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.exist?("nonexistent_directory")).to be false
    end

    it "should return true when given a regular file" do
      expect(VirtFS::VFile.exist?(@full_path)).to be true
    end

    it "should return true when given a directory" do
      expect(VirtFS::VFile.exist?(@parent_path)).to be true
    end
  end

  describe ".expand_path" do
    it "should return the same path as the standard File.expand_path, when given a dirstring" do
      expect(VirtFS::VFile.expand_path(@rel_path, @parent_path)).to eq(VfsRealFile.expand_path(@rel_path, @parent_path))
    end

    it "should return the same path as the standard File.expand_path, when using pwd" do
      VirtFS.dir_chdir(@parent_path) do
        VirtFS.cwd = VfsRealDir.getwd
        expect(VirtFS::VFile.expand_path(@rel_path)).to eq(VfsRealFile.expand_path(@rel_path))
      end
    end
  end

  describe ".extname" do
    it "should return the known extension of tempfile 1" do
      expect(VirtFS::VFile.extname('some.thing')).to eq('.thing')
    end
  end

  describe ".file?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.file?("nonexistent_directory")).to be false
    end

    it "should return true when given a regular file" do
      expect(VirtFS::VFile.file?(@full_path2)).to be true
    end

    it "should return false when given a directory" do
      expect(VirtFS::VFile.file?(@parent_path)).to be false
    end
  end

  describe ".lchmod" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod("any", "/mnt/thing")
      end.to raise_error("writes not supported");
    end
  end

  describe ".lchown" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod("any", "/mnt/thing")
      end.to raise_error("writes not supported");
    end
  end

  describe ".link" do
    it "should raise error" do
      expect do
        VirtFS::VFile.lchmod('any', '/mnt/thing')
      end.to raise_error("writes not supported");
    end
  end

  describe ".lstat" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.lstat("nonexistent_file1")
      end.to raise_error(/No such file or directory/)
    end
  end

  describe ".mtime" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.mtime("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a Time object, when given full path" do
      expect(VirtFS::VFile.mtime(@full_path)).to be_kind_of(Time)
    end

    it "should return a Time object, when given relative path" do
      VirtFS.dir_chdir(@parent_path)
      expect(VirtFS::VFile.mtime(@rel_path)).to be_kind_of(Time)
    end
  end

  describe ".rename" do
  end

  describe ".size" do
    it "should raise Errno::ENOENT when given a nonexistent file" do
      expect do
        VirtFS::VFile.size("nonexistent_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return the known size of the file" do
      expect(VirtFS::VFile.size(@full_path)).to eq(@file1_size)
    end
  end

  describe ".symlink" do
  end

  describe ".symlink?" do
  end

  describe ".zero?" do
    it "should return false when given a nonexistent file" do
      expect(VirtFS::VFile.zero?("nonexistent_file")).to be false
    end

    it "should return false when given a non-zero length file" do
      expect(VirtFS::VFile.zero?(@full_path)).to be false
    end
  end

  describe ".new" do
    it "should raise Errno::ENOENT when the file doesn't exist" do
      expect do
        VirtFS::VFile.new("not_a_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a File object - given full path" do
      expect(VirtFS::VFile.new(@full_path)).to be_kind_of(VirtFS::VFile)
    end

    it "should return a directory object - given relative path" do
      VirtFS::VDir.chdir(@parent_path)
      expect(VirtFS::VFile.new(@rel_path)).to be_kind_of(VirtFS::VFile)
    end
  end

  describe ".open" do
    it "should raise Errno::ENOENT when file doesn't exist" do
      expect do
        VirtFS::VFile.new("not_a_file")
      end.to raise_error(
        Errno::ENOENT, /No such file or directory/
      )
    end

    it "should return a File object - when no block given" do
      expect(VirtFS::VFile.open(@full_path)).to be_kind_of(VirtFS::VFile)
    end

    it "should yield a file object to the block - when block given" do
      VirtFS::VFile.open(@full_path) { |file_obj| expect(file_obj).to be_kind_of(VirtFS::VFile) }
    end

    it "should return the value of the block - when block given" do
      expect(VirtFS::VFile.open(@full_path) { true }).to be true
    end
  end
end
