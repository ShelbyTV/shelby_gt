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

  # TODO: do i need to open this up?
  attr_accessible


  ORIGIN_NETWORKS = {
    :twitter => "twitter",
    :facebook => "facebook",
    :tumblr => "tumblr",
    :shelby => "shelby"
    }
end