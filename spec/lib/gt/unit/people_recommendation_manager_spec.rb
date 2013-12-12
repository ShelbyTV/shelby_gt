require 'spec_helper'
require 'people_recommendation_manager'

# UNIT test
describe GT::PeopleRecommendationManager do

  context "constructor" do

      before(:each) do
        @user = Factory.create(:user)
      end

      it "requires a user" do
          expect { GT::PeopleRecommendationManager.new }.to raise_error(ArgumentError)
          expect { GT::PeopleRecommendationManager.new("fred") }.to raise_error(ArgumentError, "must supply valid User Object")
          expect { GT::PeopleRecommendationManager.new(@user) }.not_to raise_error
      end

      it "initializes instance variables" do
        u = GT::PeopleRecommendationManager.new(@user)
        u.instance_variable_get(:@user).should == @user
      end

  end

  context "recommend_other_users_followings" do

    before(:each) do
      @user = Factory.create(:user)
      @other_user = Factory.create(:user)
      @rm = GT::PeopleRecommendationManager.new(@user)
    end

    context "arguments" do

      it "requires a user" do
        Roll.stub_chain(:where, :fields).and_return([])
        User.stub_chain(:fields, :find).and_return([])
        expect { @rm.recommend_other_users_followings }.to raise_error(ArgumentError)
        expect { @rm.recommend_other_users_followings("fred") }.to raise_error(ArgumentError, "must supply valid User Object")
        expect { @rm.recommend_other_users_followings(@user) }.to raise_error(ArgumentError, "must supply a different user")
        expect { @rm.recommend_other_users_followings(@other_user) }.not_to raise_error
      end

    end

    context "data accessed and returned" do

      before(:each) do
        @creators = [Factory.create(:user), Factory.create(:user)]
        @followed_rolls = []
        @creators.each do |u|
          roll = Factory.create(:roll, :creator => u, :roll_type => Roll::TYPES[:special_public_real_user])
          @followed_rolls << roll
          roll_following = Factory.create(:roll_following, :roll => roll)
          @other_user.roll_followings << roll_following
        end
        @user.roll_followings << Factory.create(:roll_following, :roll => @followed_rolls[0])

        @where_query = double("where_query")
        Roll.should_receive(:where).twice().and_return(@where_query)
        @where_query.should_receive(:fields).with(:roll_type, :creator_id, :frame_count).ordered().and_return(@followed_rolls)
        @where_query.should_receive(:fields).with(:creator_id).ordered().and_return([@followed_rolls[0]])

        fields_query = double("fields_query")
        User.should_receive(:fields).with(:user_type).and_return(fields_query)
        fields_query.should_receive(:find).with([@creators[1].id]).and_return([@creators[1]])
      end

      it "returns the user ids of users who are followed by other_user but not by user" do
        expect(@rm.recommend_other_users_followings(@other_user, {:min_frames => nil})).to eql [@creators[1].id]
      end

      it "does not recommend service users" do
        @creators[1].user_type = User::USER_TYPE[:service]

        expect(@rm.recommend_other_users_followings(@other_user, {:min_frames => nil}).length).to eql 0
      end

      it "uses sample to pick a random set of users to return when :shuffle => true and a limit is passed as an option" do
        Array.any_instance.should_receive(:sample).with(1).and_call_original

        expect(@rm.recommend_other_users_followings(@other_user, {:limit => 1, :shuffle => true, :min_frames => nil}).length).to eql 1
      end

      it "uses shuffle to pick a random set of users to return when :shuffle => true and no limit is passed as an option" do
        Array.any_instance.should_receive(:shuffle).and_call_original

        expect(@rm.recommend_other_users_followings(@other_user, {:shuffle => true, :min_frames => nil}).length).to eql 1
      end

      context "doesn't call shuffle or sample" do
        before(:each) do
          Array.any_instance.should_not_receive(:sample)
          Array.any_instance.should_not_receive(:shuffle)
        end

        it "when :shuffle is false and no limit is passed" do
          @rm.recommend_other_users_followings(@other_user, {:min_frames => nil})
        end

        it "when :shuffle is false and a limit is passed" do
          @rm.recommend_other_users_followings(@other_user, {:limit => 1, :min_frames => nil})
        end
      end

    end

  end

end
