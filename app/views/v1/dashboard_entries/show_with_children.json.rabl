object @entry

attributes :id, :action, :actor_id, :read

child :frame => "frame" do
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
	
	child :creator => "creator" do
		attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id
	end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url
	end
	
	child :video => "video" do
		attributes :id, :provider_name, :provider_id, :title, :description, 
			:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count
	end
	
	child :conversation => "conversation" do
		attributes :id, :public

		child :messages => 'messages' do
			extends 'v1/messages/show'
		end
	end
	
end