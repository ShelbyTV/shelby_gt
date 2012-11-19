require 'api_clients/kiss_metrics_client'

class BetaInvite
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::BetaInvite
  
  # It must reference the User who created it
  belongs_to :sender, :class_name => 'User', :required => true
  key :sender_id, ObjectId, :abbr => :a
  
  # When used, track the new User
  # Considered unused if invitee_id==nil
  belongs_to :invitee, :class_name => 'User', :required => true
  key :invitee_id, ObjectId, :abbr => :b
  
  key :to_email_address, String, :abbr => :c, :required => true
  
  key :email_body, String, :abbr => :d
  
  key :email_subject, String, :abbr => :e
  
  attr_accessible :to_email_address, :email_body, :email_subject
  
  validates_format_of :to_email_address, :with => /\A[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\Z/
  
  def unused?() self.invitee_id == nil; end
  
  def used_by!(user)
    return false unless self.unused?
    
    user.cohorts << "beta_invited"
    user.save
    
    self.invitee = user
    self.save
    
    ShelbyGT_EM.next_tick do 
      APIClients::KissMetrics.identify_and_record(user, Settings::KissMetrics.metric['accept_invite'], {:invited_by => self.invitee})
    end
  end
  
  def path
    "/invite/#{self.id}"
  end
  
  def url
    "#{Settings::ShelbyAPI.web_root_secure}#{self.path}"
  end
  
end