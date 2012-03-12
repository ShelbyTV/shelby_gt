require 'spec_helper'

describe V1::UserController do
  
  before(:each) do
    @u1 = Factory.create(:user)
    sign_in @u1
  end
    
  describe "GET show" do
    it "assigns one user to @user" do
      User.stub(:find) { @u1 }
      get :show, :format => :json
      assigns(:user).should eq(@u1)
      assigns(:status).should eq(200)
    end
  end
  
  describe "PUT update" do
    it "updates a user successfuly" do
      u1 = mock_model(User, :update_attributes => true)
      User.stub(:find) { u1 }
      u1.should_receive(:update_attributes!).and_return(u1)
      u1.should_receive(:save!).and_return(u1)
      put :update, :id => u1.id, :user => {:nickname=>"nick"}, :format => :json
      assigns(:user).should eq(u1)
      assigns(:status).should eq(200)
    end
    
    it "updates a user UNsuccessfuly gracefully" do
      u1 = mock_model(User, :update_attributes => true)
      User.stub(:find) { u1 }
      u1.should_receive(:update_attributes!).and_return(false)
      u1.stub(:save!) { false }
      put :update, :id => u1.id, :format => :json
      assigns(:status).should eq(500)
    end
  end
end