# We are using the User model form Shelby (before rolls)
# New vs. old keys will be clearly listed

class User
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::User


  #--new keys--
  many :rolls_following

  #--old keys--

  #TODO: enforce uniqueness within Mongo
  #User.ensure_index([:nickname, 1], :unique => true, :background => true)
  
  # N.B. - we are still seeing invalid nicknames
  # seeing nicknames with spaces
  # seeing duplicates (although my auth controller primary-only stuff may fix this one)

end
