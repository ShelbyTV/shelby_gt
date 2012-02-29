class Roll
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::Roll
  
  # A Roll has many Frames, first and foremost
  many :frames, :foreign_key => :a
  
  # it was created by somebody
  belongs_to :creator,  :class_name => 'User', :required => true
  key :creator_id,      ObjectId,   :abbr => :a
  
  # it has some basic categorical info
  key :title,           String,     :abbr => :b
  key :thumbnail_url,   String,     :abbr => :c

  # public rolls can be viewed, posted to, and invited to by any user (doesn't have to be following)
  # private rolls can only be viewed, posted to, and invited to by private_collaborators
  key :public,          Boolean,  :default => true,    :abbr => :d
  
  # collaborative rolls can be posted to by users other than creator, further spcified by public? (above)
  # non-collaborative rolls can only be posted to by creator
  key :collaborative,   Boolean,  :default => true,    :abbr => :e

  # each user following this roll and when they started following
  many :following_users
  
  # for private collaborative rolls, who are the private collaborators (active or invited)
  many :private_collaborators
  
  attr_accessible :title, :thumbnail_url

end
