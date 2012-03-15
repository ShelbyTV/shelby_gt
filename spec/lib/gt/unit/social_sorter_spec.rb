require 'spec_helper'

require 'social_sorter'

# UNIT test
describe GT::SocialSorter do
  
  it "should raise ArgumentError without a valid Message" do
    lambda {
      GT::SocialSorter.sort(nil, Video.new, User.new) 
    }.should raise_error(ArgumentError)
  end
  
  it "should raise ArgumentError without a valid Video" do
    lambda {
      GT::SocialSorter.sort(Message.new, nil, User.new) 
    }.should raise_error(ArgumentError)
  end
  
  it "should raise ArgumentError without a valid User" do
    lambda {
      GT::SocialSorter.sort(Message.new, Video.new, nil) 
    }.should raise_error(ArgumentError)
  end

  it "should return false if posting_user isn't found and can't be created" do
    GT::UserManager.stub(:get_or_create_faux_user).and_return(nil)
    GT::SocialSorter.sort(Message.new, Video.new, User.new).should == false 
  end
  
  it "should return false if posting_user has no public roll" do
    GT::UserManager.stub(:get_or_create_faux_user).and_return(User.new)
    GT::SocialSorter.sort(Message.new, Video.new, User.new).should == false 
  end
  
end