require 'spec_helper'

#Functional: hit the database, treat model as black box
describe GtInterest do
  before(:each) do
    @g = GtInterest.new
    @g.email = "dan@shelby.tv"
  end
  
  context "allow_entry?" do
    
    it "should allow entry if properly invited" do
      @g.invited_at = 1.day.ago
      @g.save
      @g.reload
      @g.allow_entry?.should == true
    end
    
    it "should not allow entry if used" do
      @g.invited_at = 1.day.ago
      @g.user_created = true
      @g.save
      @g.reload
      @g.allow_entry?.should == false
    end
    
    it "should not allow entry if access is in the future" do
      @g.invited_at = 1.day.from_now
      @g.save
      @g.reload
      @g.allow_entry?.should == false
    end
    
  end
  
  context "used!" do
    it "should not allow entry after being used" do
      @g.used!(Factory.create(:user))
      @g.reload
      @g.allow_entry?.should == false
    end
    
    it "should track the user that used it"  do
      u = Factory.create(:user)
      @g.used!(u)
      @g.reload
      @g.allow_entry?.should == false
      @g.user.should == u
    end
  end
  
end