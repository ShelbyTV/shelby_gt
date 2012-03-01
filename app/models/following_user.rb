# A roll may have many users following it
# We want to track not just those IDs, but some metadata (like when they started following)

class FollowingUser
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :roll
  
  timestamps!
  
  # The user following a roll (or collaborative if this is a private roll)
  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a
  
  # People invited to private collaborative rolls
  key :invited_email_address, String, :abbr => :b
  key :invite_token,  String, :abbr => :c

end