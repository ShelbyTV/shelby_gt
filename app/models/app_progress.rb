class AppProgress
  include MongoMapper::EmbeddedDocument

  embedded_in :user

  key :onboarding, :default => false

end