require 'spec_helper'

describe VirtFS::Ext3::File do
  def cassette_path
    "spec/cassettes/file_instance.yml"
  end

  before(:all) do
  end

  before(:each) do
  end

  describe "#sysread" do
    it "should return bits read from disk" do
      expect(VirtFS::VFile.new("#{@root}/f2").sysread(7)).to eq("adfadfa")
    end
  end
end
