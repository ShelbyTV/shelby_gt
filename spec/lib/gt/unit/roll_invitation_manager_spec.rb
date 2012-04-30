require 'spec_helper'
require 'invitation_manager'

describe GT::InvitationManager do
  before(:each) do
    @inviter = Factory.create(:user)
    @user = Factory.create(:user, :gt_enabled => false, :primary_email => nil)
    @roll = Factory.create(:roll, :creator => @user)
    @email = "my@email.com"
    @gt_roll_invite_cookie = "#{@inviter.id},#{@email},#{@roll.id}"
  end

  it "should set gt_enabled" do
    GT::InvitationManager.private_roll_invite(@user, @roll, @gt_roll_invite_cookie)
    @user.gt_enabled.should eq(true)
  end
  
  it "should set email for new user if one is given" do
    GT::InvitationManager.private_roll_invite(@user, @roll, @gt_roll_invite_cookie)
    @user.primary_email.should eq(@email)
  end

end