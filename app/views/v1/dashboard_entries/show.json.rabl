object @dashboard_entry

attributes :id, :user_id, :action, :actor_id, :read

child :frame do
  extends "/v1/frame/show"
end
