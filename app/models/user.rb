# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed

class User
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User


  #--new keys--
  
  # the Rolls this user is following and when they started following
  many :roll_followings
  
  # Rolls this user has unfollowed
  # these rolls should not be auto-followed by our system
  key :rolls_unfollowed, Array, :typecase => ObjectId, :abbr => :aa

  #--old keys--
  key :name,              String
  key :nickname,          String


  #TODO: finish this list
  attr_accessible :name, :nickname, :primary_email
  
  def following_roll?(r)
    raise ArgumentException "must supply roll or roll_id" unless r
    roll_id = (r.class == Roll ? r.id : r)
    roll_followings.any? { |rf| rf.roll_id == roll_id }
  end
  
end
