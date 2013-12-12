require 'open3'

class V1::DashboardEntriesMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  before_filter :authenticate_user!, :except => [:index_for_user]

  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard
  #
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, String]  since_id the id of the dashboard entry to start from (inclusive)
  # @param [Optional, Boolean] trigger_recs if true, after responding, check if new recommendations are needed and if so, insert
  # @param [Optional, Integer] recs_version an integer representing the version of the recommendation selection algorithm to use if
  # => triggering recs, default is 1 (video graph recs only), 2 (random choice between video graph and mortar) is also supported
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index']) do
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500

      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      if (sinceId)
        cmd = "cpp/bin/dashboardIndex -u #{current_user.downcase_nickname} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
      else
        cmd = "cpp/bin/dashboardIndex -u #{current_user.downcase_nickname} -l #{limit} -s #{skip} -e #{Rails.env}"
      end

      fast_status = 0
      fast_stdout = ''
      log_text = ''
      Open3.popen3 cmd do |stdin, stdout, stderr, wait_thr|
        fast_stdout = stdout.read
        log_text = stderr.read
        fast_status = wait_thr.value.exitstatus
      end

      ShelbyGT_EM.next_tick {
        # Append logging from the c executable to our log file, but don't
        # make responding to the request wait on that
        File.open("#{Settings::CExtensions.log_file}_#{Rails.env}.log","a") do |f|
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/dashboard START---------"
          f.puts log_text
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] STATUS: #{fast_status == 0 ? 'SUCCESS' : 'ERROR'}"
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/dashboard END-----------"
        end
      }

      if !sinceId && params[:trigger_recs]
        ShelbyGT_EM.next_tick {
          recs_version = (params[:recs_version] && params[:recs_version].to_i) || 1
          recs_options = {:insert_at_random_location => true}
          recs_options[:include_mortar_recs] = false if recs_version <= 1
          # check if we need new recommendations, and if so, insert them into the stream
          GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(current_user, recs_options)
        }
      end

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end

  ##
  # Returns DashboadEntries for a "user channel"
  # Enforces security via user.public_dashboard
  #
  # Also able to return DashboardEntries for current user, if authenticated.
  # This is used by iOS.
  #
  # [GET] v1/user/:user_id/dashboard
  #
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, String]  since_id the id of the dashboard entry to start from (inclusive)
  # @param [Optional, Boolean] trigger_recs if true and the user_id is the id of the currently logged in user,
  #   after responding, check if new recommendations are needed and if so, insert
  # @param [Optional, Integer] recs_version an integer representing the version of the recommendation selection algorithm to use if
  # => triggering recs, default is 1 (video graph recs only), 2 (random choice between video graph and mortar) is also supported
  def index_for_user
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index_for_user']) do

      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500

      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      if current_user && (params[:user_id] == current_user.id.to_s)
        # A regular logged in user can view his/her own dashboard
        user = current_user
      elsif user = User.find(params[:user_id])
        # public dashboards can be viewed by anyone, even without authentication
        # logged in admin users can view any user's dashboard
        unless user.public_dashboard || (current_user && current_user.is_admin)
          renderMetalResponse(404, "{\"status\" : 401, \"message\" : \"you are not authorized to view that user's dashboard\"}")
          return
        end
      else
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"could not find the user you are looking for\"}")
        return
      end

      if (sinceId)
        cmd = "cpp/bin/dashboardIndex -u #{user.downcase_nickname} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
      else
        cmd = "cpp/bin/dashboardIndex -u #{user.downcase_nickname} -l #{limit} -s #{skip} -e #{Rails.env}"
      end

      fast_status = 0
      fast_stdout = ''
      log_text = ''
      Open3.popen3 cmd do |stdin, stdout, stderr, wait_thr|
        fast_stdout = stdout.read
        log_text = stderr.read
        fast_status = wait_thr.value.exitstatus
      end

      ShelbyGT_EM.next_tick {
        # Append logging from the c executable to our log file, but don't
        # make responding to the request wait on that
        File.open("#{Settings::CExtensions.log_file}_#{Rails.env}.log","a") do |f|
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/user/#{params[:user_id]}/dashboard START---------"
          f.puts log_text
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] STATUS: #{fast_status == 0 ? 'SUCCESS' : 'ERROR'}"
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/user/#{params[:user_id]}/dashboard END-----------"
        end
      }

      # only for the currently logged in user's dashboard
      if !sinceId && params[:trigger_recs] && user == current_user
        ShelbyGT_EM.next_tick {
          recs_version = (params[:recs_version] && params[:recs_version].to_i) || 1
          recs_options = {:insert_at_random_location => true}
          recs_options[:include_mortar_recs] = false if recs_version <= 1
          # check if we need new recommendations, and if so, insert them into the stream
          GT::VideoRecommendationManager.if_no_recent_recs_generate_rec(current_user, recs_options)
        }
      end

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else
        renderMetalResponse(500, "{\"status\" : 500, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end

    end
  end


  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index
  add_transaction_tracer :index_for_user
end
