class ShortLink
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :frame
  
  timestamps!
  
  key :twitter,       String, :abbr => :a
  key :facebook_post, String, :abbr => :b
  key :tumblr_video,  String, :abbr => :d
  key :email,         String, :abbr => :e

  #don't need anythign mass-assignable (yet)
  attr_accessible
  
  # IMPORTANT NOTE
  # The way Rails/MongoMapper implements callbacks (validations or otherwise) causes a very deep stack to be created
  # when using EmbeddedDocuments (even if you don't define any callbacks).  This gets exascerbated in EventMachine b/c of it's stack.
  # If we see SystemStackError due to "stack level too deep" when saving a Frame, we may need to disable callbacks on this
  # embedded document like we have for RollFollowing and FollowingUser.
  # Uncomment the following line to disable callbacks:
  # def self.__hack__no_callbacks() true; end
end