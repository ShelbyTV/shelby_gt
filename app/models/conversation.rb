# Post represents the conversation around a Frame (Frames and Posts share a 1:1 relationship).
#
# An external social post (tweet, fb post, tumblr, &c.) will generate a Post, as will rolling something.
# All messages (including the original) are captured as Post.messages, thus creating a conversation


class Conversation
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Conversation
  
  
  # It must reference a video (the same video that the Frame references)
  belongs_to :video, :required => true
  key :video_id, ObjectId, :abbr => :a

  # was this public (ie shelby, tweet, tumblr, public FB) or private-ish (ie facebook non-public post)
  key :public, Boolean, :abbr => :b
  
  # The individual messages of the conversation
  many :messages
  # The way Rails/MongoMapper implements callbacks (validations or otherwise) causes a very deep stack to be created
  # when using EmbeddedDocuments (even if you don't define any callbacks).  This gets exascerbated in EventMachine b/c of it's stack.
  # If we see SystemStackError due to "stack level too deep" when saving a Conversation, we may need to disable embedded doc callbacks 
  # Uncomment the following line to disable callbacks:
  # embedded_callbacks_off
  
  # A Conversation references it's original Frame, and each Frame has only one Conversation
  # If a tweet (or other *external* social post) comes in that references more than one video: multiple Conversations will be created, referencing different Frames, Videos
  # Although Frames can be dupe'd, and each dupe'd Frame will reference the same Conversation, from the Conversation's POV we only care about the original Frame
  belongs_to :frame
  key :frame_id, ObjectId, :abbr => :c


  key :from_deeplink, Boolean, :abbr => :d, :default => false
  
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
