require 'discussion_roll_utils'
require 'open3'

class V1::FrameMetalController < MetalController
  include AbstractController::Logger
  include AbstractController::Callbacks
  include AbstractController::Helpers
  include Devise::Controllers::Helpers
  include GT::DiscussionRollUtils

  ##
  # Returns frames in a roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/roll/:roll_id/frames
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  # @param [Optional, String]  since_id the id of the frame to start from (inclusive)
  # @param [Optional, String]  token The access token granting view permission of a private discussion Roll
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index']) do
      limit = params[:limit] ? params[:limit].to_i : 20
      skip = params[:skip] ? params[:skip] : 0
      limit = 500 if limit.to_i > 500
      sinceId = params[:since_id]

      if params[:token] and token_valid_for_discussion_roll?(params[:token], params[:roll_id])
        if (sinceId)
          cmd = "cpp/bin/frameIndex --permissionGranted -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
        else
          cmd = "cpp/bin/frameIndex --permissionGranted -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}"
        end
      elsif (current_user)
        if (sinceId)
          cmd = "cpp/bin/frameIndex -u #{current_user.id} -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
        else
          cmd = "cpp/bin/frameIndex -u #{current_user.id} -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}"
        end
      else
        if (sinceId)
          cmd = "cpp/bin/frameIndex -r #{params[:roll_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
        else
          cmd = "cpp/bin/frameIndex -r #{params[:roll_id]} -l #{limit} -s #{skip} -e #{Rails.env}"
        end
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
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/roll/#{params[:roll_id]}/frames START---------"
          f.puts log_text
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] STATUS: #{fast_status == 0 ? 'SUCCESS' : 'ERROR'}"
          if fast_status != 0
            f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] -------------------C OUTPUT FOR DEBUGGING START-----------------------------"
            f.puts fast_stdout
            f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] -------------------C OUTPUT FOR DEBUGGING END-------------------------------"
          end
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] ---------RUBY SAYS: HANDLE v1/roll/#{params[:roll_id]}/frames END-----------"
        end
      }

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index

  ##
  # Returns frames in a user's personal roll
  #   AUTHENTICATION OPTIONAL
  #
  # [GET] /v1/user/:id/personal/frames
  # @param [Required, String] id The id of the user
  # @param [Optional, Integer] limit limit the number of frames returned, default 20
  # @param [Optional, Integer] skip the number of frames to skip, default 0
  # @param [Optional, String]  since_id the id of the frame to start from (inclusive)
  def index_for_users_public_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['frame']['index_for_users_public_roll']) do
      # default params
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 500 if limit.to_i > 500

      skip = params[:skip] ? params[:skip] : 0
      sinceId = params[:since_id]

      if (sinceId)
        cmd = "cpp/bin/frameIndex -u #{params[:user_id]} -l #{limit} -s #{skip} -i #{sinceId} -e #{Rails.env}"
      else
        cmd = "cpp/bin/frameIndex -u #{params[:user_id]} -l #{limit} -s #{skip} -e #{Rails.env}"
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
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] --RUBY SAYS: HANDLE v1/user/#{params[:user_id]}/rolls/personal/frames START-"
          f.puts log_text
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] STATUS: #{fast_status == 0 ? 'SUCCESS' : 'ERROR'}"
          f.puts "[#{Time.now.strftime("%m-%d-%Y %T")}] --RUBY SAYS: HANDLE v1/user/#{params[:user_id]}/rolls/personal/frames END---"
        end
      }

      if (fast_status == 0)
        renderMetalResponse(200, fast_stdout)
      else
        renderMetalResponse(404, "{\"status\" : 404, \"message\" : \"fast index failed with status #{fast_status}\"}")
      end
    end
  end
  include ::NewRelic::Agent::Instrumentation::ControllerInstrumentation
  add_transaction_tracer :index_for_users_public_roll

end
