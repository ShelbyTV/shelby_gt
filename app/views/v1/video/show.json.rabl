object @video

attributes :id, :provider_name, :provider_id, :title, :description,
	:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count,
	:like_count, :tracked_liker_count, :first_unplayable_at, :last_unplayable_at

child :recs => "recs" do
  attributes :recommended_video_id, :score
end