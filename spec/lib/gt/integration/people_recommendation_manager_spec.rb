require 'spec_helper'
require 'people_recommendation_manager'

# INTEGRATION test
describe GT::PeopleRecommendationManager do

  before(:each) do
    @user = Factory.create(:user)
    @other_user = Factory.create(:user)
    @rm = GT::PeopleRecommendationManager.new(@user)
  end

  context "recommend_other_users_followings" do

    before(:each) do
      @creators = [Factory.create(:user), Factory.create(:user), Factory.create(:user), Factory.create(:user)]
      @followed_rolls = []
      @creators.each_with_index do |u, i|
        roll = Factory.create(:roll, :creator => u, :roll_type => Roll::TYPES[:special_public_real_user])
        @followed_rolls << roll
        @other_user.roll_followings << Factory.create(:roll_following, :roll => roll)
        @user.roll_followings << Factory.create(:roll_following, :roll => roll) if i == @creators.length - 1
      end
    end

    it "returns the user ids of users who are followed by other_user but not by user" do
      MongoMapper::Plugins::IdentityMap.clear
      expect(@rm.recommend_other_users_followings(@other_user)).to eql @creators[0..-2].map { |u| u.id }
    end

    it "only considers user public rolls and promoted faux user public rolls" do
      @followed_rolls[1].roll_type = Roll::TYPES[:special_public_upgraded]
      @followed_rolls[1].save
      # this one should get excluded
      @followed_rolls[2].roll_type = Roll::TYPES[:special_public]
      @followed_rolls[2].save
      MongoMapper::Plugins::IdentityMap.clear
      expect(@rm.recommend_other_users_followings(@other_user)).to eql @creators[0..1].map { |u| u.id }
    end

    it "does not recommend service users" do
      @creators[0].user_type = User::USER_TYPE[:service]
      @creators[0].save
      MongoMapper::Plugins::IdentityMap.clear
      res = @rm.recommend_other_users_followings(@other_user)
      expect(res).not_to include @creators[0].id
      expect(res.length).to eql 2
    end

    it "does not recommend the user on whom the recommendations are based" do
      @followed_rolls[0].creator = @other_user
      @followed_rolls[0].save
      MongoMapper::Plugins::IdentityMap.clear
      res = @rm.recommend_other_users_followings(@other_user)
      expect(res).not_to include @creators[0].id
      expect(res).not_to include @other_user.id
      expect(res.length).to eql 2
    end

    it "will not return the same user twice" do
      new_roll = Factory.create(:roll, :creator => @creators[0], :roll_type => Roll::TYPES[:special_public_real_user])
      @other_user.roll_followings << Factory.create(:roll_following, :roll => new_roll)
      MongoMapper::Plugins::IdentityMap.clear

      expect(@rm.recommend_other_users_followings(@other_user).count).to eql 3
    end

  end

end
