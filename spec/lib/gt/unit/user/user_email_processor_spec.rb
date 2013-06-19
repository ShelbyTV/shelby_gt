# encoding: UTF-8

require 'spec_helper'

require 'user_email_processor'

# UNIT test
describe GT::UserEmailProcessor do

  before(:each) do
    @user = Factory.create(:user)
  end

  context "send_rec_email" do

    context "private methods" do
      before(:each) do
        @email_processor = GT::UserEmailProcessor.new
      end

      context "real user check" do
        it "should return true if its real user type" do
          @user["ag"] = true
          @user["ac"] = User::USER_TYPE[:real]
          @email_processor.real_user_check(@user).should eql true
        end

        it "should return true if its converted user type" do
          @user["ag"] = true
          @user["ac"] = User::USER_TYPE[:converted]
          @email_processor.real_user_check(@user).should eql true
        end

        it "should return null if its real or converted user type but not gt_enabled" do
          @user["ag"] = false
          @email_processor.real_user_check(@user).should eql false
        end

        it "should return false if user is fake" do
          @user["ac"] = User::USER_TYPE[:faux]
          @email_processor.real_user_check(@user).should eql false
        end
      end
    end

  end
end
