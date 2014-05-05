require 'spec_helper'

# UNIT test
describe PublicRollExporter do
  before(:each) do
    @user = Factory.create(:user)
    @user_uid = 'uid'
    @email = 'someemail@somedomain.com'
  end

  it "calls export_public_roll with correct parameters" do
    User.should_receive(:find).with(@user_uid).and_return(@user)
    GT::UserManager.should_receive(:export_public_roll).with(@user, @email)

    PublicRollExporter.perform(@user_uid, @email)
  end

  it "does nothing if the user is not found" do
    User.stub(:find)
    GT::UserManager.should_not_receive(:export_public_roll)

    PublicRollExporter.perform(@user_uid, @email)
  end

end