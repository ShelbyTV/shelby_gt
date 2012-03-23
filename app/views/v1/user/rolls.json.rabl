object @user

child :roll_followings do
	glue :roll do
		attributes :id, :title, :thumbnail_url, :public, :collaborative
	end
end

