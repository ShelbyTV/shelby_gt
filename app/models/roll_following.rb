# A user can follow many rolls
# We want to track not just those IDs, but some metadata (like when they started following)

class RollFollowing
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :user
  
  timestamps!
  
  belongs_to :roll, :required => true
  key :roll_id, ObjectId, :abbr => :a

  # We may embed lots of these which results in a stack level too deep issue (b/c of the way MM/Rails does validation chaining)
  # But since we don't use validations or callbacks, we can hack around this issue:
  def self.__hack__no_callbacks() true; end
  
end