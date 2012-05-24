collection @rolls

attributes :id, :collaborative, :public, :creator_id, :origin_network

code :title do |r|
	if current_user.upvoted_roll_id == :id
		"hearted"
	else
		r.title
	end
end

code :thumbnail_url do |r|
	if current_user.upvoted_roll_id == :id
		Settings::ShelbyAPI.web_root + "/images/assets/favorite_roll_avatar.png"
	else
		r.thumbnail_url
	end
end
