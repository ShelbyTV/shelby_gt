# A roll may have many users following it
# We want to track not just those IDs, but some metadata (like when they started following)

class FollowingUser
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :roll
  
  timestamps!
  
  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a

end