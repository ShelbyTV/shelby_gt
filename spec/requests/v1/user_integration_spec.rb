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
      
      it "should return cohorts with user" do
        @u1.cohorts = ["a", "b"]
        @u1.save
        
        get '/v1/user'
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_size(2).at_path("result/cohorts")
        response.body.should be_json_eql(["a", "b"]).at_path("result/cohorts")
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
      
      context "rolls/following" do
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
          parse_json(response.body)["result"][0]["id"].should == r1.id.to_s
          parse_json(response.body)["result"][0]["followed_at"].should == @u1.roll_followings[0].id.generation_time.to_f
        end
      
        it "should not show a users rolls if the supplied user_id is NOT the current_users" do
          u2 = Factory.create(:user)
          get '/v1/user/'+u2.id+'/rolls/following'
          response.body.should be_json_eql(403).at_path("status")
        end
        
        it "should return rolls in followed_at descending order" do
          r0 = Factory.create(:roll, :creator => @u1)
          r0.add_follower(@u1)
          r1 = Factory.create(:roll, :creator => @u1)
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => @u1)
          r2.add_follower(@u1)
          
          #adjust the roll followings id which in turn is used as creation time
          @u1.roll_following_for(r1).update_attribute(:_id, BSON::ObjectId.from_time(50.days.ago))
          @u1.roll_following_for(r2).update_attribute(:_id, BSON::ObjectId.from_time(10.days.ago))
          @u1.roll_following_for(r0).update_attribute(:_id, BSON::ObjectId.from_time(1.days.ago))
          @u1.save
          
          get '/v1/user/'+@u1.id+'/rolls/following'
          response.body.should be_json_eql(200).at_path("status")
          parse_json(response.body)["result"].class.should eq(Array)
          parse_json(response.body)["result"][0]["id"].should == r0.id.to_s
          parse_json(response.body)["result"][1]["id"].should == r2.id.to_s
          parse_json(response.body)["result"][2]["id"].should == r1.id.to_s
        end
      
        it "should have the first three rolls be mine, hearts, watch later" do
          r0 = Factory.create(:roll, :creator => @u1)
          r0.add_follower(@u1)
          wl_roll = Factory.create(:roll, :creator => @u1)
          wl_roll.add_follower(@u1)
          public_roll = Factory.create(:roll, :creator => @u1)
          public_roll.add_follower(@u1)
          hearts_roll = Factory.create(:roll, :creator => @u1, :roll_type => Roll::TYPES[:special_upvoted])
          hearts_roll.add_follower(@u1)
          r3 = Factory.create(:roll, :creator => @u1)
          r3.add_follower(@u1)
          @u1.public_roll = public_roll
          @u1.upvoted_roll = hearts_roll
          @u1.watch_later_roll = wl_roll
          @u1.save
        
          get '/v1/user/'+@u1.id+'/rolls/following'
          parse_json(response.body)["result"][0]["id"].should == public_roll.id.to_s
          parse_json(response.body)["result"][0]["roll_type"].should == public_roll.roll_type
          parse_json(response.body)["result"][1]["id"].should == hearts_roll.id.to_s
          parse_json(response.body)["result"][2]["id"].should == wl_roll.id.to_s
        end
      end
      
      context "rolls/postable" do
        it "should only return the subset of rolls that the user can post to" do
          public_roll = Factory.create(:roll, :creator => @u1, :collaborative => false)
          public_roll.add_follower(@u1)
          @u1.public_roll = public_roll
          
          upvoted_roll = Factory.create(:roll, :creator => @u1, :collaborative => false)
          upvoted_roll.add_follower(@u1)
          @u1.upvoted_roll = upvoted_roll
          
          r1 = Factory.create(:roll, :creator => @u1)
          r1.add_follower(@u1)
          r2 = Factory.create(:roll, :creator => Factory.create(:user), :public => false, :collaborative => true)
          r2.add_follower(@u1)
          r3 = Factory.create(:roll, :creator => Factory.create(:user), :public => true, :collaborative => false)
          r3.add_follower(@u1)
          
          @u1.save
        
          get '/v1/user/'+@u1.id+'/rolls/postable'
          response.body.should have_json_size(4).at_path("result")
          parse_json(response.body)["result"][0]["id"].should == public_roll.id.to_s
          parse_json(response.body)["result"][1]["id"].should == upvoted_roll.id.to_s
          parse_json(response.body)["result"][2]["id"].should == r1.id.to_s
          parse_json(response.body)["result"][3]["id"].should == r2.id.to_s
        end
      end
      
      it "should return frames if they are asked for in roll followings" do
        url = 'http://url.here'
        r1 = Factory.create(:roll, :creator => @u1, :first_frame_thumbnail_url => url)
        r1.add_follower(@u1)
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["first_frame_thumbnail_url"].should eq(url)
      end
            
      it "should have correct watch_later and public roll ids returned" do
        @u1.watch_later_roll_id = 12345
        @u1.public_roll_id = 54321
        @u1.save
        get '/v1/user/'+@u1.id
        parse_json(response.body)["result"]["watch_later_roll_id"].should eq(@u1.watch_later_roll_id)
        parse_json(response.body)["result"]["personal_roll_id"].should eq(@u1.public_roll_id)
      end
      
      it "should return :creator_nickname, :following_user_count which are specially injected in the controller" do
        r1 = Factory.create(:roll, :creator => @u1)
        r1.add_follower(@u1)
        get '/v1/user/'+@u1.id+'/rolls/following'
        response.body.should be_json_eql(200).at_path("status")
        parse_json(response.body)["result"][0]["creator_nickname"].should == @u1.nickname
        parse_json(response.body)["result"][0]["following_user_count"].should == 1
      end
      
      context "valid_token route" do
        
        it "should render an error if user doen't have the specified authentication" do
          get '/v1/user/'+@u1.id+'/is_token_valid?provider=facebook'
          response.body.should be_json_eql(404).at_path("status")
        end
              
        it "should return error if a provider is not specified or is not supporte" do
          get '/v1/user/'+@u1.id+'/is_token_valid'
          response.body.should be_json_eql(404).at_path("status")
          
          get '/v1/user/'+@u1.id+'/is_token_valid?provider=funckymoney'
          response.body.should be_json_eql(404).at_path("status")
        end
      end

      context "autocomplete" do
        it "should return autocomplete info with user if the supplied user_id is the current_users" do
          get '/v1/user/' + @u1.id
          response.body.should have_json_path("result/autocomplete")
        end

       it "should NOT return autocomplete info with user if the supplied user_id is not the current_users" do
          u2 = Factory.create(:user)
          get '/v1/user/' + u2.id
          response.body.should_not have_json_path("result/autocomplete")
        end
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
      
      it "should update nickname and that should be reflected in new downcase_nickname" do
        new_nick = "WhAtaintUniQUE--123"
        put "/v1/user/#{@u1.id}?nickname=#{new_nick}"
        @u1.reload
        @u1.downcase_nickname.should == new_nick.downcase
      end
      
      it "should update the user's public_roll title when changing the user nickname if the roll has nickname as its title" do
        roll = Factory.build(:roll, :title => @u1.nickname)
        roll.creator = @u1
        roll.save
        @u1.public_roll = roll
        @u1.save
        put '/v1/user/'+@u1.id+'?nickname=pharoah'
        @u1.reload
        @u1.public_roll.title.should == "pharoah"
      end

      it "should NOT update the user's public_roll title when changing the user nickname if the roll does not have nickname as its title" do
        roll = Factory.build(:roll, :title => 'not-the-users-nickname')
        roll.creator = @u1
        roll.save
        @u1.public_roll = roll
        @u1.save
        put '/v1/user/'+@u1.id+'?nickname=ramses'
        @u1.reload
        @u1.public_roll.title.should == "not-the-users-nickname"
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
        response.body.should be_json_eql(401).at_path("status")
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