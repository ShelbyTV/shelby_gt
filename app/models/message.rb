# A Conversation around a Frame is made up of many Messages

class Message
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :conversation
  
  timestamps!
  
  # If this came from twitter, facebook, tumblr, &c. store the network it's from
  key :origin_network, String, :abbr => :a
  # and the ID used by that network to references this post
  key :origin_id, String, :abbr => :b
  # and the user's ID on that network
  key :origin_user_id, String, :abbr => :c
  
  # If this is a Shelby message, the user_id as an Object 
  belongs_to :user
  key :user_id, ObjectId, :abbr => :d
  
  # The Shelby or external nickname
  key :nickname, String, :required => true, :abbr => :e
  
  # The Shelby or external real name
  key :realname, String, :required => true, :abbr => :f
  
  # The Shelby or external user avatar
  key :user_image_url, String, :required => true, :abbr => :g
  
  # The message itself
  key :text, String, :required => true, :abbr => :h
  
  # is this public (ie tweet, tumblr post) or private/semi-private (ie Facebook limited share)
  key :public, Boolean, :abbr => :i

  # TODO: do i need to open this up?
  attr_accessible
  
  # IMPORTANT NOTE
  # The way Rails/MongoMapper implements callbacks (validations or otherwise) causes a very deep stack to be created
  # when using EmbeddedDocuments (even if you don't define any callbacks).  This gets exascerbated in EventMachine b/c of it's stack.
  # If we see SystemStackError due to "stack level too deep" when saving a Conversation, we may need to disable callbacks on this
  # embedded document like we have for RollFollowing and FollowingUser.
  # Uncomment the following line to disable callbacks:
  # def self.__hack__no_callbacks() true; end


  ORIGIN_NETWORKS = {
    :twitter => "twitter",
    :facebook => "facebook",
    :tumblr => "tumblr",
    :shelby => "shelby"
    }
end