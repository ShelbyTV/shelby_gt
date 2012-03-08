object @dashboard_entry

attributes :id, :action, :actor_id, :user_id

glue @roll do
	attributes :id, creator_id, :title, :thumbnail_url, :public, :collaborative, :following_users
end

glue @frame do
	attributes :id, :score, :upvoters, :frame_ancestors, :frame_children
end

glue @conversation do
	
end