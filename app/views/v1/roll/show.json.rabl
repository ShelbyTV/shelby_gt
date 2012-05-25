object @roll

attributes :id, :collaborative, :public, :creator_id, :origin_network

code :title do |r|
	if params[:heart_roll]
		"♥'d Roll"
	else
		r.title
	end
end

code :thumbnail_url do |r|
	if params[:heart_roll]
		Settings::ShelbyAPI.web_root + "/images/assets/favorite_roll_avatar.png"
	else
		r.thumbnail_url
	end
end

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image
	end
end