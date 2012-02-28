require 'spec_helper'

describe Post do
  before(:each) do
    @post = Post.new
  end
  
  it "should use the database post" do
    @post.database.name.should =~ /.*post/
  end
  
end
