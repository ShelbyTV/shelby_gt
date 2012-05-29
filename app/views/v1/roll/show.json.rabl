object @roll

attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url, :origin_network, :genius

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image
	end
end
