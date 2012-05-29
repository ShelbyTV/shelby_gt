class Recommendation
  include MongoMapper::EmbeddedDocument

  key :recommended_video_id, ObjectId, :required => true, :abbr => :a
  key :score, Float, :required => true, :abbr => :b

  embedded_in :video
end
