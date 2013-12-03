child @video => :video do
  attributes :id, :provider_name, :provider_id
end

child @likers => :likers do
  attributes :user_id, :name, :nickname, :user_image, :user_image_original, :has_shelby_avatar
  attribute :public_roll_id => :personal_roll_id
end