object @object

node :id do
	@object.id
end

node "video_thumbnail" do
	@object.video_thumbnail
end

Rails.logger.info self.class