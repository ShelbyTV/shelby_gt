# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed

class User
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User


  #--new keys--
  
  # the Rolls this user is following and when they started following
  many :roll_followings

  #--old keys--
  key :name,              String
  key :nickname,          String

  # N.B. - we are still seeing invalid nicknames
  # seeing nicknames with spaces
  # seeing duplicates (although my auth controller primary-only stuff may fix this one)


  #TODO: finish this list
  attr_accessible :name, :nickname, :primary_email
  
end
