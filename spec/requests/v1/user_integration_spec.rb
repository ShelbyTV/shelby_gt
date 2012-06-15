require 'spec_helper' 

describe 'v1/user' do

  context 'logged in' do
    before(:each) do
      @u1 = Factory.create(:user)
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'
    end
    
    describe "GET" do
      it "should return user info on success" do
        get '/v1/user'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")
      end
      
      it "should have a user app progress attr" do
        get '/v1/user'
        response.body.should have_json_path("result/app_progress")
      end
      
      it "should not have a roll_followings attr" do
        get '/v1/user'
        response.body.should_not have_json_path("result/roll_followings")
      end

      it "should wrap with callback when requesting via jsonp" do
        get '/v1/user/?callback=jQuery17108599677098863208_1335973680689&include_rolls=true&_=1335973682178'
        response.body.should =~ /^\W*jQuery17108599677098863208_1335973680689/
      end
      
      it "should return user info for another user besides herself" do
        u2 = Factory.create(:user)
        get '/v1/user/'+u2.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")        
      end
      
      it "should get a user by querying by nickname" do
        u2 = Factory.create(:user)
        u2.downcase_nickname = u2.nickname.downcase
        u2.save
        get '/v1/user/'+u2.nickname
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"]["nickname"].should eq(u2.nickname)
      end
      
      it "should show user is logged in" do
        get '/v1/signed_in'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/signed_in")
        parse_json(response.body)["result"]["signed_in"].should eq(true)
      end
      
      it "should show a users rolls if the supplied user_id is the current_users" do
        r1 = Factory.create(:roll, :creator => @u1)
        r1.add_follower(@u1)
        r2 = Factory.create(:roll, :creator => @u1)
        r2.add_follower(@u1)
        @u1.upvoted_roll = r2
        @u1.save
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"].class.should eq(Array)
      end
      
      it "should not show a users rolls if the supplied user_id is NOT the current_users" do
        u2 = Factory.create(:user)
        get '/v1/user/'+u2.id+'/rolls/following'
        response.body.should be_json_eql(403).at_path("status")
      end
      
      it "should have the first and second rolls be special" do
        r1 = Factory.create(:roll, :creator => @u1)
        r1.add_follower(@u1)
        r2 = Factory.create(:roll, :creator => @u1)
        r2.add_follower(@u1)
        r3 = Factory.create(:roll, :creator => @u1)
        r3.add_follower(@u1)
        @u1.public_roll = r1
        @u1.upvoted_roll = r2
        @u1.save
        
        get '/v1/user/'+@u1.id+'/rolls/following'
        parse_json(response.body)["result"][0]["id"].should eq(r1.id.to_s)
        parse_json(response.body)["result"][1]["id"].should eq(r2.id.to_s)
      end
      
      it "should return frames if they are asked for in roll followings" do
        r1 = Factory.create(:roll, :creator => @u1)
        r1.add_follower(@u1)
        url = 'http://url.here'
        v = Factory.create(:video, :thumbnail_url => url)
        f = Factory.create(:frame, :creator => @u1, :roll => r1, :video => v)
        get '/v1/user/'+@u1.id+'/rolls/following?frames=true'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["frames"][0]["video"]["thumbnail_url"].should eq(url)
      end
            
      it "should have correct watch_later and public roll ids returned" do
        @u1.watch_later_roll_id = 12345
        @u1.public_roll_id = 54321
        @u1.save
        get '/v1/user/'+@u1.id
        parse_json(response.body)["result"]["watch_later_roll_id"].should eq(@u1.watch_later_roll_id)
        parse_json(response.body)["result"]["personal_roll_id"].should eq(@u1.public_roll_id)
      end
      
    end
    
    describe "PUT" do
      it "should return user info on success" do
        put '/v1/user/'+@u1.id+'?name=Barack%20Obama'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/name")
        parse_json(response.body)["result"]["name"].should eq("Barack Obama")
      end
      
      it "should return an error if a validation fails" do
        put '/v1/user/'+@u1.id+'?nickname=signout'
        response.body.should be_json_eql(404).at_path("status")
      end
      
      it "should update a users app_progress successfuly" do
        put '/v1/user/'+@u1.id+'?app_progress[test]=2'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/app_progress")
        parse_json(response.body)["result"]["app_progress"]["test"].should eq("2")
      end
      
    end
  end
  
  context "not logged in" do
    describe "GET" do
      it "should return user if a user is found" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/nickname")
      end
      
      it "should return an error if a user is not found" do
        get '/v1/user'
        response.body.should have_json_type(Integer).at_path("status")
        response.body.should be_json_eql(404).at_path("status")
      end
      
      it "should show user is logged in" do
        get '/v1/signed_in'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result/signed_in")
        parse_json(response.body)["result"]["signed_in"].should eq(false)
      end
      
      it "should return error if trying to get a users rolls" do
        u = Factory.create(:user)
        get '/v1/user/'+u.id+'/rolls/following'
        response.body.should be_json_eql(401).at_path("status")
      end
      
    end
    
    describe "PUT" do
      it "should not be able to update user info" do
        u = Factory.create(:user)
        put '/v1/user/'+u.id+'?nickname=nick'
        response.status.should eq(401)
      end
      
    end    
  end
  
end