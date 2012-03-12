object @conversation

attributes :id, :public, :video_id

child :messages do
	attributes :id, :text, :public, :nickname, :realname
end