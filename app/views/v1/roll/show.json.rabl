object @roll

attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url

child @following_users do
	attributes :id, :nickname, :name, :user_image
end

child @frames do
	attributes :id
end