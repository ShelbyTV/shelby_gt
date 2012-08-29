class V1::DashboardEntriesMetalController < ActionController::Metal
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  before_filter :authenticate_user!

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard
  # 
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, String]  since_id the id of the dashboard entry to start from (inclusive)
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index']) do
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500
          
      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      if (sinceId) 
        fast_stdout = `cpp/bin/dashboardIndex -u #{current_user.downcase_nickname} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
      else
        fast_stdout = `cpp/bin/dashboardIndex -u #{current_user.downcase_nickname} -l #{limit} -s #{skip} -e #{Rails.env}`
      end
      fast_status = $?.to_i

      if (fast_status == 0)
        self.status = 200
        self.content_type = "application/json"
        self.response_body = "#{fast_stdout}"
      else 
        self.status = 404
        self.content_type = "application/json"
        self.response_body = "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}"
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index
end
