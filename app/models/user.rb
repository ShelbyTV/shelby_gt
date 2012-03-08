# encoding: UTF-8

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
  
  # The one special roll for a user: their public roll
  belongs_to :public_roll, :class_name => 'Roll'
  key :public_roll_id, ObjectId, :abbr => :ab
  
  # When we create a User just for their public Roll, we mark them faux=true
  key :faux, Boolean, :default => false, :abbr => :ac
  
  has_many :dashboard_entries, :foreign_key => :a

  #--old keys--
  
  many :authentications
  
  key :name,                  String
  #Mongo string matches are case sensitive and regex queries w/ case insensitivity won't actually use index
  #So we downcase the nickname into User and then query based on that (which is now indexed)
  key :nickname,              String, :required => true
  key :downcase_nickname,     String
  key :user_image,            String
  key :user_image_original,   String
  key :primary_email,         String
  
  key :server_created_on,     String, :default => "gt"
  


  #TODO: finish this list
  attr_accessible :name, :nickname, :primary_email
  
  validates_uniqueness_of :nickname
  
  def following_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    roll_followings.any? { |rf| rf.roll_id == roll_id }
  end
  
  def unfollowed_roll?(r)
    raise ArgumentError, "must supply roll or roll_id" unless r
    roll_id = (r.is_a?(Roll) ? r.id : r)
    rolls_unfollowed.include? roll_id
  end
  
end
