class V1::PrioritizedDashboardEntriesController < ApplicationController
  before_filter :authenticate_user!

  ##
  # Returns prioritized dashboad entries, sorted by score, with the given parameters.
  #
  # ***
  # NB: This controller is temporary to allow us to test and build out frontend.
  #     During that build, this will be moved to fast C API.
  #     API consumers should not notice any difference in the data.
  # ***
  #
  # [GET] v1/prioritized_dashboard
  #
  # @param [Optional, Integer] limit The number of entries to return (default 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Integer] min_score The minimum acceptable score for an entry, below which entries won't be returned (default 0)
  def index
    # default params
    limit = params[:limit] ? params[:limit].to_i : 20
    # put an upper limit on the number of entries returned
    limit = 500 if limit.to_i > 500
    skip = params[:skip] ? params[:skip] : 0
    min_score = params[:min_score] ? params[:min_score] : 0
    
    @pdb_entries = PrioritizedDashboardEntry.for_user_id(current_user.id).ranked.limit(limit).skip(skip).where(:score.gte => min_score).all

    # Pull all the children into the identity map for a little bit of efficiency
    @frames = Frame.find((@pdb_entries.map {|pdb_entry| pdb_entry.frame_id}).compact.uniq)
    @videos = Video.find((@frames.map {|frame| frame.video_id}).compact.uniq)
    @rolls = ::Roll.find((@frames.map {|frame| frame.roll_id}).compact.uniq)
    @conversations = Conversation.find((@frames.map {|frame| frame.conversation_id}).compact.uniq)
    user_ids = @frames.map { |frame| frame.creator_id }
    user_ids += @pdb_entries.map { |e| e.friend_sharers_array + e.friend_viewers_array + e.friend_likers_array + e.friend_rollers_array + e.friend_complete_viewers_array }
    @users = User.find(user_ids.compact.uniq)

    @status = 200
  end

end