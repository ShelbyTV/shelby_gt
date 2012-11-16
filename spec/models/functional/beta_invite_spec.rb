require 'spec_helper'

#Functional: hit the database, treat model as black box
describe BetaInvite do
  
  context "database" do
    
    it "should have an index on [sender_user_id]" do
      indexes = BetaInvite.collection.index_information.values.map { |v| v["key"] }
      indexes.should include({"a"=>1})
    end
  
  end

  context "used_by!" do
    before(:each) do
      @sender = Factory.create(:user)
      @accepter = Factory.create(:user)
      @beta_invite = Factory.create(:beta_invite, :sender => @sender)
    end

    it "should send a notification to the invite sender" do
      GT::NotificationManager.should_receive(:check_and_send_invite_accepted_notification).with(@sender, @accepter).and_return(nil)
      @beta_invite.used_by! @accepter
    end
  end
  
end