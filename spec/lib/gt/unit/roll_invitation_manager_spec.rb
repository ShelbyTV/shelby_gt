require 'spec_helper'
require 'invitation_manager'

describe GT::InvitationManager do
  before(:each) do
    @inviter = Factory.create(:user)
    @user = Factory.create(:user, :gt_enabled => false, :primary_email => nil)
    @roll = Factory.create(:roll, :creator => @user)
    @email = Factory.next :primary_email
    @gt_roll_invite_cookie = "#{@inviter.id},#{@email},#{@roll.id},#{@roll.id}"
  end

  it "should call user's gt_enable!" do
    @user.should_receive(:gt_enable!).once
    GT::InvitationManager.private_roll_invite(@user, @gt_roll_invite_cookie)
  end
  
  it "should set email for new user if one is given" do
    GT::InvitationManager.private_roll_invite(@user, @gt_roll_invite_cookie)
    @user.primary_email.should eq(@email)
    @user.gt_enabled.should == true
  end
  
  it "should backfill that user for the given roll" do
    GT::Framer.should_receive(:backfill_dashboard_entries).with(@user, @roll, 20)
    GT::InvitationManager.private_roll_invite(@user, @gt_roll_invite_cookie)
  end

end