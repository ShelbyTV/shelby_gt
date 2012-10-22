class BetaInvite
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::BetaInvite
  
  # It must reference the User who created it
  belongs_to :sender, :class_name => 'User', :required => true
  key :sender_user_id, ObjectId, :abbr => :a
  
  # When used, track the new User
  # Considered unused if invitee_id==nil
  belongs_to :invitee, :class_name => 'User', :required => true
  key :invitee_id, ObjectId, :abbr => :b
  
  key :to_email_address, String, :abbr => :c, :required => true
  
  key :email_body, String, :abbr => :d
  
  key :email_subject, String, :abbr => :e
  
  attr_accessible :to_email_address, :email_body, :email_subject
  
  def used?() self.invitee_id != nil; end
  
  def used_by!(user)
    self.invitee = user
    self.save
  end
  
end