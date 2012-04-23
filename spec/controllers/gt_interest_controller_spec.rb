require 'spec_helper'

describe V1::GtInterestController do

  describe "POST create" do
    it "sets email and priority code on success" do
      post :create, :email => "spinosa@gmail.com", :priority_code => "TNW2012", :format => :json
      response.should be_success
      assigns(:interest).email.should == "spinosa@gmail.com"
      assigns(:interest).priority_code.should == "TNW2012"
    end

    it "works without priority code" do
      post :create, :email => "spinosa@gmail.com", :format => :json
      response.should be_success
      assigns(:interest).email.should == "spinosa@gmail.com"
    end
    
    it "returns 400 without email" do
      post :create, :format => :json
      response.should_not be_success
      assigns(:status).should eq(400)
      assigns(:message).should eq("must have a valid email")
    end
  end
  
end