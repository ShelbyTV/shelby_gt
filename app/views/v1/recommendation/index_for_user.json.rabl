collection @results

glue :dashboard_entry do
  attributes :id, :user_id, :action, :actor_id
end

child :frame do
  extends "v1/frame/show"
end