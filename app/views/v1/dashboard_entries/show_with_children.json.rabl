object @entry

self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_db_info']) do
	attributes :id, :action, :actor_id, :read
end	

self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_frame_children_info']) do
	child :frame => "frame" do
    self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_frame_info']) do
			attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
		end
		
    self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_creator_info']) do
			child :creator => "creator" do
				attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id
			end
		end
		
    self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_roll_info']) do
			child :roll => "roll" do
				attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url
			end
		end
		
    self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_video_info']) do
			child :video => "video" do
				attributes :id, :provider_name, :provider_id, :title, :description, 
					:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count
			end
		end
		
    self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_conversation_info']) do
			child :conversation => "conversation" do
				attributes :id, :public

    		self.class.trace_execution_scoped(['Custom/dashboard_entries_index/render_message_info']) do
					child :messages => 'messages' do
						attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public

						code :created_at do |c|
							time_ago_in_words(c.created_at) + ' ago' if c.created_at
						end
					end
				end
			end
		end
		
	end
end