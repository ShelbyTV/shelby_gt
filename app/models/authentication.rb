class Authentication
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  embedded_in :user 
  
  key :provider,  String
  key :uid,       String
  key :oauth_token,   String
  key :oauth_secret,  String
  
  #oauth user info
  key :name,        String
  key :nickname,    String
  key :email,       String
  key :first_name,  String
  key :last_name,   String
  key :location,    String
  key :description, String
  key :image,       String
  key :phone,       String
  key :urls,        String
  key :user_hash,   String
  key :gender,      String
  key :timezone,    String
  key :permissions, Array  
  
  timestamps!
  
end