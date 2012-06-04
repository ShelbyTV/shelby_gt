# encoding: utf-8
#
# Folks will submit their email address from the Gate and it's captured here.
#
class GtInterest
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::GtInterest
  
  key :email, String, :requried => true, :abbr => :a
  validates_presence_of :email
  
  key :priority_code, String, :abbr => :b
  
  # If this is nil, they aren't allowed in yet
  key :invited_at, Time, :abbr => :c
  
  key :user_created, Boolean, :default => false, :abbr => :d
  
  # the user created
  belongs_to :user
  key :user_id, ObjectId, :abbr => :e
  
  def allow_entry?
    !!(self.invited_at and self.invited_at < Time.now and !self.user_created?)
  end
  
  def used!(user)
    self.user_created = true
    self.user = user
    self.save(:validate => false)
  end
  
  def access_granted_link
    "http://gt.shelby.tv/?gt_access_token=#{self.id}"
  end
  
end