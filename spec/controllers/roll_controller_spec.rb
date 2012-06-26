require 'spec_helper'
require "link_shortener"

describe V1::RollController do
  before(:each) do
    @u1 = Factory.create(:user)
    sign_in @u1
    @roll = Factory.create(:roll, :creator => @u1)
    @roll.public = false
    Roll.stub!(:find).and_return(@roll)
  end
  
  describe "GET show" do
    it "assigns one roll to @roll" do
      get :show, :id => @roll.id, :format => :json
      assigns(:roll).should eq(@roll)
    end

    describe "by subdomain" do
      before(:each) do
        @roll.subdomain = @roll.title
      end

      it "gets a roll by subdomain if it is asked for and the roll has its subdomain active" do
        Roll.stub_chain(:where, :find_one).and_return(@roll)
        
        @roll.subdomain_active = true
        get :show, :id => @roll.subdomain, :format => :json
        assigns(:roll).should eq(@roll)
      end

      it "does not get a roll by subdomain if it is asked for and the roll does not have its subdomain active" do
        Roll.stub_chain(:where, :find_one).and_return(nil)
        
        @roll.subdomain_active = false
        get :show, :id => @roll.subdomain, :format => :json
        assigns(:roll).should eq(nil)
      end
    end

    it "gets a users public roll if its asked for" do
      @u1.public_roll = @roll; @u1.save
      get :show_users_public_roll, :user_id => @u1.id, :format => :json
      assigns(:roll).should eq(@roll)
    end
    
    it "gets a users heart roll if its asked for" do
      @u1.upvoted_roll = @roll; @u1.save
      get :show_users_heart_roll, :user_id => @u1.id, :format => :json
      assigns(:roll).should eq(@roll)
    end
    
    it "will show a public roll if you're not signed in" do
      @roll.public = true; @roll.save
      sign_out @u1
      
      get :show, :id=> @roll.id.to_s, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "returns rolls when browse is called" do
      @r1 = Factory.create(:roll, :creator => @u1)
      @r2 = Factory.create(:roll, :creator => @u1)
      @r3 = Factory.create(:roll, :creator => @u1)
      @r4 = Factory.create(:roll, :creator => @u1)
      roll_arry = [@r1,@r2,@r3,@r4]
      Roll.stub!(:find).and_return(roll_arry)
      
      get :browse, :rolls => [@r1.id, @r2.id, @r3.id, @r4.id], :format => :json
      assigns(:rolls).should eq(roll_arry)
    end
  end
  
  describe "PUT update" do
    it "updates a roll successfuly" do
      @roll.should_receive(:update_attributes!).and_return(@roll)
      put :update, :id => @roll.id, :public => false , :format => :json
      assigns(:status).should eq(200)
      assigns(:roll).should eq(@roll)
    end
    
    it "updates a roll unsuccessfuly returning 400" do
      @roll.should_receive(:update_attributes!).and_raise(ArgumentError)
      put :update, :id => @roll.id, :public => false, :format => :json
      assigns(:status).should eq(400)
    end

    it "updates a record to an invalid state returning 409" do
      document = double ("document")
      document.stub_chain(:errors, :full_messages, :join).and_return("Subdomain is reserved")
      exception = MongoMapper::DocumentNotValid.new(document)

      @roll.should_receive(:update_attributes!).and_raise(exception)
      put :update, :id => @roll.id, :title => 'anal', :format => :json
      assigns(:status).should eq(409)
    end
  end
  
  describe "POST create" do
    before(:each) do
      @roll = Factory.create(:roll, :creator_id => @u1.id)
      Roll.stub!(:find).and_return(@roll)
    end
    
    it "creates and assigns one roll to @roll" do
      Roll.stub!(:new).and_return(@roll)
      @roll.stub(:valid?).and_return(true)
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :public => false, :collaborative => false, :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:roll).public?.should == false
      assigns(:roll).collaborative.should == false
      assigns(:status).should eq(200)
    end
    
    it "creates and assigns one roll to @roll without thumbnail" do
      Roll.stub!(:new).and_return(@roll)
      @roll.stub(:valid?).and_return(true)
      post :create, :title =>"foo", :public => false, :collaborative => false, :format => :json
      assigns(:roll).should eq(@roll)
      assigns(:status).should eq(200)
    end
    
    it "fails if user not signed in" do
      sign_out @u1
      post :create, :title =>"foo", :thumbnail_url => "http://bar.com", :public => false, :collaborative => false, :format => :json
      response.should_not be_success
    end
    
    it "returns 400 if there is no title" do
      sign_in @u1
      post :create, :thumbnail_url => "http://foofle", :public => false, :collaborative => false, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("title required")
    end
    
    it "returns 400 if public is not set" do
      sign_in @u1
      post :create, :title => "title", :collaborative => true, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("public required")
    end
    
    it "returns 400 if collaborative is not set" do
      sign_in @u1
      post :create, :title => "title", :public => true, :format => :json
      assigns(:status).should eq(400)
      assigns(:message).should eq("collaborative required")
    end
    
    it "returns 409 if reserved subdomain is set" do
      sign_in @u1
      post :create, :title => "anal", :public => true, :collaborative => false, :format => :json
      assigns(:status).should eq(409)
    end

  end
  
  describe "POST share" do
    before(:each) do
      sign_in @u1
      @roll = Factory.create(:roll, :creator => @u1)
      Roll.stub!(:find).and_return(@roll)
      resp = {"awesm_urls" => [{"service"=>"twitter", "parent"=>nil, "original_url"=>"http://henrysztul.info", "redirect_url"=>"http://henrysztul.info?awesm=shl.by_4", "awesm_id"=>"shl.by_4", "awesm_url"=>"http://shl.by/4", "user_id"=>nil, "path"=>"4", "channel"=>"twitter", "domain"=>"shl.by"}]}
      Awesm::Url.stub(:batch).and_return([200, resp])
    end
    
    context "social share" do
      it "should return 200 if the user posts succesfully to destination" do
        post :share, :roll_id => @roll.id.to_s, :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(200)      
      end
    
      it "should return 404 if destination is not an array" do
        post :share, :roll_id => @roll.id.to_s, :destination => "twitter", :text => "testing", :format => :json
        assigns(:status).should eq(404)
      end
    
      it "should return 404 if the user cant post to the destination" do
        post :share, :roll_id => @roll.id.to_s, :destination => ["facebook"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("that user cant post to that destination")      
      end
    
      it "should not post if the destination is not supported" do
        post :share, :roll_id => @roll.id.to_s, :destination => ["awesome_service"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("we dont support that destination yet :(")
      end
    
      it "should return 404 if a text or destination is not present" do
        post :share, :roll_id => @roll.id.to_s, :destination => ["twitter"], :format => :json
        assigns(:status).should eq(404)
      
        post :share, :roll_id => @roll.id.to_s, :text => "testing", :format => :json
        assigns(:status).should eq(404)
      
        assigns(:message).should eq("a destination and a text is required to post")
      end
    
      it "should return 404 if roll is private and you try to share to a social network" do
        roll = stub_model(Roll, :public => false)
        Roll.stub!(:find).and_return(roll)
        post :share, :roll_id => roll.id.to_s, :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("that roll is private, can not share to twitter")
      end
    
      it "should return 404 if roll not found" do
        Roll.stub!(:find).and_return(nil)
        post :share, :destination => ["twitter"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
        assigns(:message).should eq("could not find roll with id ")
      end
    end
    
    context "email share" do
      it "should return 200 when sharing a private roll via email" do
        GT::SocialPoster.should_receive(:post_to_email).once
        
        roll = stub_model(Roll, :public => false)
        Roll.stub!(:find).and_return(roll)
        post :share, :roll_id => roll.id.to_s, :destination => ["email"], :text => "testing", :addresses => "spinosa@gmail.com", :format => :json
        assigns(:status).should eq(200)
      end
      
      it "should return 404 if you don't includ email addresses" do
        GT::SocialPoster.should_receive(:post_to_email).exactly(0).times
        
        roll = stub_model(Roll, :public => false)
        Roll.stub!(:find).and_return(roll)
        post :share, :roll_id => roll.id.to_s, :destination => ["email"], :text => "testing", :format => :json
        assigns(:status).should eq(404)
      end
    end
    
  end
  
  describe "POST join/leave" do
    before(:each) do
      @u = Factory.create(:user)
      @fu = Factory.create(:user)
      @r = Factory.create(:roll, :creator => @u, :following_users=>[{:user_id=>@u1.id}] )
      Roll.stub!(:find).and_return(@r)
    end
    
    it "should return 200 if the user joins a roll succesfully" do
      @r.following_users=[]; @r.save
      post :join, :roll_id => @r.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return 200 if the user leaves a roll succesfully" do
      post :leave, :roll_id => @r.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return 200 if user is already a memeber of the roll" do
      @r.add_follower(@fu)
      @r.save
      sign_in(@fu)
      post :join, :roll_id => @r.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "should return 404 if user isn't allowed to leave a roll" do
      @r.following_users=[{:user_id=>@fu.id}]; @r.save
      post :leave, :roll_id => @r.id, :format => :json
      assigns(:status).should eq(404)
    end
    
    it "should return 404 if roll is not found" do
      Roll.stub!(:find).and_return(nil)
      post :join, :roll_id => '123', :format => :json
      assigns(:status).should eq(404)
      
      post :leave, :roll_id => '123', :format => :json
      assigns(:status).should eq(404)
    end
    
  end
  
  describe "DELETE destroy" do
    before(:each) do
      @u1 = Factory.create(:user)
      sign_in @u1
      
      @roll = Factory.create(:roll, :creator => @u1)
      Roll.stub!(:find).and_return(@roll)
    end
    
    it "destroys a roll successfuly" do
      @roll.should_receive(:destroy).and_return(true)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(200)
    end
    
    it "unsuccessfuly destroys a roll returning 404" do
      @roll.should_receive(:destroy).and_return(false)
      delete :destroy, :id => @roll.id, :format => :json
      assigns(:status).should eq(404)
    end
  end
  
end