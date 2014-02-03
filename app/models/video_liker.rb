class VideoLiker
  include MongoMapper::EmbeddedDocument

  # the user who liked the video
  belongs_to :user, :required => true
  key :user_id, ObjectId, :abbr => :a

  # denormalized data from the liking user for more efficient retrieval, see user.rb model for comments on their meaning
  key :name, String, :abbr => :b
  key :nickname, String, :abbr => :c, :required => true
  key :user_image, String, :abbr => :d
  key :user_image_original, String, :abbr => :e
  key :has_shelby_avatar, Boolean, :abbr => :f, :required => true

  belongs_to :public_roll, :required => true
  key :public_roll_id, ObjectId, :abbr => :g

  # lookup the user who liked the video and update the denormalized user data stored on this document
  def refresh_user_data!
    user = self.user

    self.name = user.name
    self.nickname = user.nickname
    self.user_image = user.user_image
    self.user_image_original = user.user_image_original
    self.has_shelby_avatar = user.has_shelby_avatar
  end
end