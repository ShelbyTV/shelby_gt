# encoding: utf-8
#
# Folks will submit their email address from the Gate and it's captured here.
#
class GtInterest
  include MongoMapper::Document
  
  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::GtInterest
  
  key :email, String, :requried => true, :abbr => :a
  validates_presence_of :email
  
  key :priority_code, String, :abbr => :b
  
  # If this is nil, they aren't allowed in yet
  key :invited_at, Time, :abbr => :c
  
  key :user_created, Boolean, :default => false, :abbr => :d
  
  # the user created
  belongs_to :user
  key :user_id, ObjectId, :abbr => :e
  
end