require 'spec_helper'

describe VirtFS::Ext3 do
  def cassette_path
    "spec/cassettes/ext3.yml"
  end

  it 'has a version number' do
    expect(VirtFS::Ext3::VERSION).not_to be nil
  end
end
