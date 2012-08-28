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
  
  # The user_id of the real Shelby user or the faux user
  belongs_to :user
  key :user_id, ObjectId, :abbr => :d, :required => true
  
  # The Shelby or external nickname
  key :nickname, String, :required => true, :abbr => :e
  
  # The Shelby or external real name
  key :realname, String, :required => true, :abbr => :f
  
  # The external user avatar
  key :user_image_url, String, :required => true, :abbr => :g
  
  # Does the user has a deterministic Shelby avatar?  (If so, we should display it)
  # NB: A Shelby avatar that was set after this message was created will not change this attribute to true
  key :user_has_shelby_avatar, Boolean, :abbr => :j, :default => false
  
  # The message itself
  key :text, String, :abbr => :h
  
  # is this public (ie tweet, tumblr post) or private/semi-private (ie Facebook limited share)
  key :public, Boolean, :abbr => :i

  #don't need anythign mass-assignable (yet)
  attr_accessible
  
  # IMPORTANT NOTE
  # The way Rails/MongoMapper implements callbacks (validations or otherwise) causes a very deep stack to be created
  # when using EmbeddedDocuments (even if you don't define any callbacks).  This gets exascerbated in EventMachine b/c of it's stack.
  # If we see SystemStackError due to "stack level too deep" when saving a Conversation, we may need to disable callbacks on this
  # embedded document like we have for RollFollowing and FollowingUser.
  # Uncomment the following line to disable callbacks:
  # def self.__hack__no_callbacks() true; end

  def created_at() self.id.generation_time; end

  ORIGIN_NETWORKS = {
    :twitter => "twitter",
    :facebook => "facebook",
    :tumblr => "tumblr",
    :shelby => "shelby"
    }
end