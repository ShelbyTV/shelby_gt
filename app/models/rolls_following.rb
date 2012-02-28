# A user can follow many rolls
# We want to track not just those IDs, but some metadata (like when they started following)

class RollsFollowing
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :user
  
  timestamps!
  
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :a

end