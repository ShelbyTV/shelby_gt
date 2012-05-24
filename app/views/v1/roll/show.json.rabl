object @roll

attributes :id, :collaborative, :public, :creator_id, :thumbnail_url, :origin_network

code :title do |r|
	if params[:heart_roll]
		"hearted"
	else
		r.title
	end
end

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image
	end
end