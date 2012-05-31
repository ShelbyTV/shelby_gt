# Post represents the conversation around a Frame (Frames and Posts share a 1:1 relationship).
#
# An external social post (tweet, fb post, tumblr, &c.) will generate a Post, as will rolling something.
# All messages (including the original) are captured as Post.messages, thus creating a conversation


class Conversation
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Conversation
  
  #TODO: We want to be using identity maps as much as possible, but we need to be intelligently clearing caches first!
  #plugin MongoMapper::Plugins::IdentityMap
  
  # It must reference a video (the same video that the Frame references)
  belongs_to :video, :required => true
  key :video_id, ObjectId, :abbr => :a

  # was this public (ie shelby, tweet, tumblr, public FB) or private-ish (ie facebook non-public post)
  key :public, Boolean, :abbr => :b
  
  # The individual messages of the conversation
  many :messages
  
  # A Conversation references it's original Frame, and each Frame has only one Conversation
  # If a tweet (or other *external* social post) comes in that references more than one video: multiple Conversations will be created, referencing different Frames, Videos
  # Although Frames can be dupe'd, and each dupe'd Frame will reference the same Conversation, from the Conversation's POV we only care about the original Frame
  belongs_to :frame
  key :frame_id, ObjectId, :abbr => :c


  key :deep, Boolean, :abbr => :d, :default => false
  
  #don't need anythign mass-assignable (yet)
  attr_accessible
  
  def created_at() self.id.generation_time; end

  def self.first_including_message_origin_id(mid)
    Conversation.first( :conditions => { 'messages.b' => mid } )
  end
  
  def find_message_by_id(id)
    self.messages.select { |m| m.id.to_s == id } .first
  end

end
