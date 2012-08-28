object @shelby_message

attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public, :user_has_shelby_avatar

code :created_at do |c|
	concise_time_ago_in_words(c.created_at) if c.created_at
end