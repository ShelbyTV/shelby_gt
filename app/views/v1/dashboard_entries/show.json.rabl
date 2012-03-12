object @entry

attributes :id, :action, :actor_id, :read, :roll_id, :frame_id, :user_id

node(:video_id) { |m| m.frame.video_id }

node(:conversation_id) { |m| m.frame.conversation_id }