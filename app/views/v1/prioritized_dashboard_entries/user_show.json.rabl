object @user

attributes :id, :name, :nickname, :user_image_original, :user_image, :has_shelby_avatar, :user_type, :public_roll_id, :gt_enabled

child :authentications do
  attributes :uid, :provider, :nickname
end