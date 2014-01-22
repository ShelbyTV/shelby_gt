object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :header_image_file_name, :content_updated_at, :creator_thumbnail_url => :thumbnail_url
attributes :display_thumbnail_url => :thumbnail_url

node do |r|
  creator = r.creator
  result = {}
  if creator
    if creator.user_type == User::USER_TYPE[:faux] && creator.authentications && !creator.authentications.empty?
      result[:creator_nickname] = creator.authentications[0].nickname
      result[:creator_name] = creator.authentications[0].name
    else
      result[:creator_nickname] = creator.nickname
      result[:creator_name] = creator.name
    end
    result[:creator_has_shelby_avatar] = (creator.avatar_file_name && (creator.avatar_file_name.length > 0))
    result[:creator_image_original] = creator.user_image_original
    result[:creator_image] = creator.user_image
    result[:creator_avatar_updated_at] = creator.avatar_updated_at
    child creator.authentications => :creator_authentications do
      attributes :uid, :provider, :nickname, :name
    end
  end
  result[:discussion_roll_participants] = r.discussion_roll_participants if r.roll_type == Roll::TYPES[:user_discussion_roll]
  result[:following_user_count] = r.following_users.count
  result[:subdomain] = r.subdomain if r.subdomain_active

  result
end

# not too slow b/c we're only dealing with a single roll
code :followed_at do |r|
  if current_user and (rf = current_user.roll_following_for(r))
    rf.id.generation_time.to_f
  else
    0
  end
end

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image, :has_shelby_avatar
	end
end

if @insert_discussion_roll_access_token == true
  node(:token) do |r|
    GT::DiscussionRollUtils.encrypt_roll_user_identification(r, @user_identifier)
  end
end