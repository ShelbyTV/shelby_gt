require 'spec_helper'

describe ApplicationController do
  before(:all) do
    @ac = ApplicationController.new
  end
  
  context "cookies" do
    it "should be able to turn a cookie into a hash" do
      c = "first=val1,second=val2,third=val=3"
      h = @ac.cookie_to_hash(c)
      h.class.should == Hash
      h.size.should == 3
      h[:first].should == "val1"
      h[:second].should == "val2"
      h[:third].should == "val=3"
    end
    
    it "should handle empty cookie" do
      c = ""
      h = @ac.cookie_to_hash(c)
      h.class.should == Hash
      h.size.should == 0
      
      c = nil
      h = @ac.cookie_to_hash(c)
      h.class.should == Hash
      h.size.should == 0
    end
    
    it "should be able to pull :authenticated_user_id from cookie" do
      c = "crap=crap,authenticated_user_id=someid,csrf_token=lkjasdf897sa@$%==@$5wef=@$%"
      @ac.cookie_to_hash(c)[:authenticated_user_id].should == "someid"
    end
    
    it "should be able to pull :csrf_token from cookie" do
      c = "crap=crap,authenticated_user_id=someid,csrf_token=lkjasdf897sa@$%==@$5wef=@$%"
      @ac.cookie_to_hash(c)[:csrf_token].should == "lkjasdf897sa@$%==@$5wef=@$%"
    end
    
    it "should be able to pull :csrf_token from cookie when it ends with equals sign" do
      c = "authenticated_user_id=4d7a8942f6db247853000001,csrf_token=Zp1YApVGLga+NNJFTA2p2WYurq7+pAdP3Ynmb6VLTh0="
      @ac.cookie_to_hash(c)[:csrf_token].should == "Zp1YApVGLga+NNJFTA2p2WYurq7+pAdP3Ynmb6VLTh0="
    end
  end
  
end