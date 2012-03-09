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
  
end