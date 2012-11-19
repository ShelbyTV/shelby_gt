class AppProgress
  include MongoMapper::EmbeddedDocument
  
  embedded_in :user 

  key :onboarding, Integer
  
end