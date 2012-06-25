require 'spec_helper'

require 'social_sorter'

# UNIT test
describe GT::SocialSorter do
  
  context "conversations and deepness" do
    it "should keep track of deep" do
      observer = Factory.create(:user)
      existing_user = Factory.create(:user)
      existing_user_nick, existing_user_provider, existing_user_uid = "nick1", "ss_1#{rand.to_s}", "uid001#{rand.to_s}"
      
      video = Factory.create(:video)
      existing_user_random_msg = Message.new
      existing_user_random_msg.nickname = existing_user_nick
      existing_user_random_msg.origin_network = existing_user_provider
      existing_user_random_msg.origin_user_id = existing_user_uid
      existing_user_random_msg.origin_id = rand.to_s
      existing_user_random_msg.public = true
      res = GT::SocialSorter.sort(existing_user_random_msg, {:video => video, :from_deep => true}, observer)
      frame = res[:frame]
      frame.conversation.from_deeplink.should == true
    end
  end
  
  it "should raise ArgumentError without a valid Message" do
    lambda {
      GT::SocialSorter.sort(nil, {:video => Factory.create(:video), :from_deep => false}, User.new) 
    }.should raise_error(ArgumentError)
  end
  
  it "should raise ArgumentError without a valid Video" do
    lambda {
      GT::SocialSorter.sort(Message.new, {:video => nil, :from_deep => false}, User.new) 
    }.should raise_error(ArgumentError)
  end
  
  it "should raise ArgumentError without a valid User" do
    lambda {
      GT::SocialSorter.sort(Message.new, {:video => Factory.create(:video), :from_deep => false}, nil) 
    }.should raise_error(ArgumentError)
  end

  it "should return false if posting_user isn't found and can't be created" do
    GT::UserManager.stub(:get_or_create_faux_user).and_return(nil)
    GT::SocialSorter.sort(Message.new, {:video => Factory.create(:video), :from_deep => false}, User.new).should == false 
  end
  
  it "should return false if posting_user has no public roll" do
    GT::UserManager.stub(:get_or_create_faux_user).and_return(User.new)
    GT::SocialSorter.sort(Message.new, {:video => Factory.create(:video), :from_deep => false}, User.new).should == false 
  end
  
end
