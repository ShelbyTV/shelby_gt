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
          # check if we need new recommendations, and if so, insert them into the stream
          GT::RecommendationManager.if_no_recent_recs_generate_rec(current_user, { :insert_at_random_location => true })
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
  def index_for_user
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index_for_user']) do
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500

      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      # user for "user channel" or current user if requested with proper id
      user = User.where(:id => params[:user_id], :public_dashboard => true).first
      if !user and current_user and current_user.id.to_s == params[:user_id]
        user = current_user
      end

      if user
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

        if (fast_status == 0)
          renderMetalResponse(200, fast_stdout)
        else
          renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
        end
      else
        renderMetalResponse(404, "could not find the user you are looking for")
      end
    end
  end


  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index
  add_transaction_tracer :index_for_user
end
