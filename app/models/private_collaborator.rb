# A private roll can have many private collaborators
# Some will be users, but some are invited non-shelbyers

class PrivateCollaborator
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :roll
  
  timestamps!

  # If there is a  Shelby user collaborating, they will be linked here
  belongs_to :user
  key :user_id, ObjectId, :abbr => :a
  
  # Otherwise, this person has only been invited...
  key :invited_email_address, String, :abbr => :b
  key :invite_token,  String, :abbr => :c

end