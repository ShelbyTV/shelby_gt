object @entry

attributes :id, :action, :actor_id, :read
child :frame => "frame" do |f|
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id

	child :creator => "creator" do
		attributes :id, :name, :nickname, :user_image_original, :user_image, :faux, :public_roll_id, :gt_enabled
	end

	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url
	end
	
	child :video => "video" do
		attributes :id, :provider_name, :provider_id, :title, :description, 
			:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count
	end

	child :conversation => "conversation" do
		attributes :id, :public

		child :messages => 'messages' do
			attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public
		end
	end
end
