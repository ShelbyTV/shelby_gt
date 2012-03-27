# Post represents the conversation around a Frame (Frames and Posts share a 1:1 relationship).
#
# An external social post (tweet, fb post, tumblr, &c.) will generate a Post, as will rolling something.
# All messages (including the original) are captured as Post.messages, thus creating a conversation


class Conversation
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Conversation
  
  # A Conversation only references a single Frame, and each Frame has only one Conversation
  # If a tweet (or other *external* social post) comes in that references more than one video: multiple Conversation will be created, referencing different Frames and Videos.
  has_one :frame, :foreign_key => :c, :required => true

  # It must reference a video (the same video that the Frame references)
  belongs_to :video, :required => true
  key :video_id, ObjectId, :abbr => :a

  # was this public (ie shelby, tweet, tumblr, public FB) or private-ish (ie facebook non-public post)
  key :public, Boolean, :abbr => :b
  
  # The individual messages of the conversation
  many :messages
  
  #don't need anythign mass-assignable (yet)
  attr_accessible

  def self.first_including_message_origin_id(mid)
    Conversation.first( :conditions => { 'messages.b' => mid } )
  end
  
  def find_message_by_id(id)
    self.messages.select { |m| m.id.to_s == id } .first
  end

end
