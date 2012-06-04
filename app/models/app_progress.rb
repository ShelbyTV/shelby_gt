class AppProgress
  include MongoMapper::EmbeddedDocument
  
  embedded_in :user 
  
  # Users App Progress for user education
  #key :example,               Boolean, :default => true
  
end