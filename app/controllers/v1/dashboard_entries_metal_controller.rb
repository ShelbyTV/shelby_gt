class V1::DashboardEntriesMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  before_filter :user_authenticated?, :except => [:index_for_user]

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
        renderMetalResponse(200, fast_stdout)
      else
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end

    ##
  # Returns dashboad entries for another user, with the given parameters.
  #
  # [GET] v1/user/:user_id/dashboard
  #
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, String]  since_id the id of the dashboard entry to start from (inclusive)
  def index_for_user
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index_for_user']) do

      #TODO: only allow certain allowed dasboards to be returned
      #return render_error() unless ["id1", "id2"].include? params[:user_id]

      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500

      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      # lookup user
      if user = User.find(params[:user_id])
        if (sinceId)
          fast_stdout = `cpp/bin/dashboardIndex -u #{user.downcase_nickname} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}`
        else
          fast_stdout = `cpp/bin/dashboardIndex -u #{user.downcase_nickname} -l #{limit} -s #{skip} -e #{Rails.env}`
        end
        fast_status = $?.to_i

        if (fast_status == 0)
          renderMetalResponse(200, fast_stdout)
        else
          renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
        end
      else
        render_error(404, "could not find the user you are looking for")
      end
    end
  end


  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index
end
