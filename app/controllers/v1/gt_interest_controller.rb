class V1::GtInterestController < ApplicationController  

  protect_from_forgery :except => :create
  
  ##
  # Creates and returns one GtInterest
  #
  # [POST] /v1/gt_interest
  #
  # @param email [Required, String] users email address
  # @param priority_code [Optional, String] a priority code to be associated
  # @return [GtInterest] the GtInterest object created
  def create
    @interest = GtInterest.new(:email => params[:email], :priority_code => params[:priority_code])
    if @interest.save
      @status = 200

      # Don't want to email when using this model to test "subscribe via email" signups
      unless /subscribe_to_roll:.+/.match(params[:priority_code])
        ShelbyGT_EM.next_tick { GtInterestMailer.interest_autoresponse(@interest.email).deliver }
      end
    else
      render_error(400, "must have a valid email")
    end
  end

  
end
