require 'spec_helper' 

class DiscussionRollTester
  include GT::DiscussionRollUtils
end

describe 'v1/discussion_roll' do
  context 'logged in' do
    before(:each) do
      @tester = DiscussionRollTester.new
      
      @frame = Factory.create(:frame)
      @u1, @u2 = Factory.create(:user), Factory.create(:user)
      set_omniauth(:uuid => @u1.authentications.first.uid)
      get '/auth/twitter/callback'      
    end
    
    describe "POST create" do
      it "should create new roll" do
        lambda {
          post "/v1/discussion_roll?frame_id=#{@frame.id}&message=msg&participants=#{CGI.escape @u2.primary_email}"
        }.should change { Roll.count } .by(1)
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        
        parse_json(response.body)["result"]["creator_id"].should == @u1.id.to_s
        parse_json(response.body)["result"]["roll_type"].should == Roll::TYPES[:user_discussion_roll]
        parse_json(response.body)["result"]["public"].should == false
        parse_json(response.body)["result"]["collaborative"].should == true
      end
      
      it "should find already created roll" do
        roll = @tester.create_discussion_roll_for(@u2, @tester.convert_participants(@u1.primary_email))
        
        lambda {
          post "/v1/discussion_roll?frame_id=#{@frame.id}&message=msg&participants=#{CGI.escape @u2.primary_email}"
        }.should_not change { Roll.count }
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        
        parse_json(response.body)["result"]["id"].should == roll.id.to_s
      end
      
      it "should send emails to everybody but roll creator" do
        emails = [Factory.next(:primary_email), Factory.next(:primary_email), Factory.next(:primary_email)]
        lambda {
          post "/v1/discussion_roll?frame_id=#{@frame.id}&message=msg&participants=#{CGI.escape emails.join(';')}"
        }.should change { ActionMailer::Base.deliveries.count } .by(emails.size)
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
      end
    end
    
    describe "GET show" do
      it "should show the roll if the user is following it (no token)" do
        roll = @tester.create_discussion_roll_for(@u1, [])
        
        get "/v1/discussion_roll/#{roll.id}"
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
        
        parse_json(response.body)["result"]["id"].should == roll.id.to_s
      end
      
      it "should not show the roll if the user isn't following it (not token)" do
        @roll = @tester.create_discussion_roll_for(@u2, [])
        
        get "/v1/discussion_roll/#{@roll.id}"
        
        response.body.should be_json_eql(404).at_path("status")
      end
    end
    
    describe "POST create_message" do
      before(:each) do
        @frame = Factory.create(:frame)
      end
      
      it "should send emails to everybody but message creator" do
        emails = [Factory.next(:primary_email), Factory.next(:primary_email), Factory.next(:primary_email)]
        roll = @tester.create_discussion_roll_for(@u1, emails)
        GT::Framer.re_roll(@frame, @u1, roll, true)

        lambda {
          post "/v1/discussion_roll/#{roll.id}/messages?message=msg"
        }.should change { ActionMailer::Base.deliveries.count } .by(emails.size)
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
      end
      
      it "should post the message with correct info for actual user" do
        emails = [Factory.next(:primary_email), Factory.next(:primary_email), Factory.next(:primary_email)]
        roll = @tester.create_discussion_roll_for(@u1, emails)
        GT::Framer.re_roll(@frame, @u1, roll, true)

        lambda {
          post "/v1/discussion_roll/#{roll.id}/messages?message=themsg"
        }.should change { roll.frames.first.conversation.messages.size } .by(1)
        
        roll.frames.first.conversation.messages[0].user.should == @u1
        roll.frames.first.conversation.messages[0].text.should == "themsg"
        roll.frames.first.conversation.messages[0].origin_network.should == Message::ORIGIN_NETWORKS[:shelby]
      end
    end
  end
  
  context "logged out" do
    before(:each) do      
      @tester = DiscussionRollTester.new

      @u1, @u2 = Factory.create(:user), Factory.create(:user)

      @frame = Factory.create(:frame)
      @roll = @tester.create_discussion_roll_for(@u2, @tester.convert_participants(@u1.primary_email))
    end
    
    describe "GET show" do
      it "should show the roll if user has a valid token" do
        token = GT::DiscussionRollUtils.encrypt_roll_user_identification(@roll, Factory.next(:primary_email))
        get "/v1/discussion_roll/#{@roll.id}?token=#{CGI.escape Base64.encode64 token}"
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
      end
      
      it "should not show the roll with a bad token" do
        token = "bad token here"
        get "/v1/discussion_roll/#{@roll.id}?token=#{CGI.escape Base64.encode64 token}"
        
        response.body.should be_json_eql(404).at_path("status")
      end
    end
    
    describe "POST create_message" do
      it "should send emails to everybody but message creator" do
        msg_poster_email = Factory.next(:primary_email)
        emails = [msg_poster_email, Factory.next(:primary_email), Factory.next(:primary_email)]
        roll = @tester.create_discussion_roll_for(@u1, emails)
        GT::Framer.re_roll(@frame, @u1, roll, true)

        lambda {
          token = GT::DiscussionRollUtils.encrypt_roll_user_identification(roll, msg_poster_email)
          post "/v1/discussion_roll/#{roll.id}/messages?message=msg&token=#{CGI.escape Base64.encode64 token}"
        }.should change { ActionMailer::Base.deliveries.count } .by(emails.size)
        
        response.body.should be_json_eql(200).at_path("status")
        response.body.should have_json_path("result")
      end
      
      it "should post the message with correct info for non-user" do
        msg_poster_email = Factory.next(:primary_email)
        emails = [msg_poster_email, Factory.next(:primary_email), Factory.next(:primary_email)]
        roll = @tester.create_discussion_roll_for(@u1, emails)
        GT::Framer.re_roll(@frame, @u1, roll, true)

        lambda {
          token = GT::DiscussionRollUtils.encrypt_roll_user_identification(roll, msg_poster_email)
          post "/v1/discussion_roll/#{roll.id}/messages?message=itsamsg&token=#{CGI.escape Base64.encode64 token}"
        }.should change { roll.frames.first.conversation.messages.size } .by(1)
        
        roll.frames.first.conversation.messages[0].user.should == nil
        roll.frames.first.conversation.messages[0].text.should == "itsamsg"
        roll.frames.first.conversation.messages[0].origin_network.should == Message::ORIGIN_NETWORKS[:shelby]
        roll.frames.first.conversation.messages[0].nickname.should == msg_poster_email
      end
    end
  end
end
