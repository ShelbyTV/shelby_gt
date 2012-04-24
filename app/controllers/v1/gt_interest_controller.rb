class V1::GtInterestController < ApplicationController  

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
      #TODO: send email: "you've been added to our wait list, but to get in and reserve your username get invited to a roll from someone who's in the alpha…"
      #EM.next_tick { SendEmailTo(@interest.email) }
    else
      render_error(400, "must have a valid email")
    end
  end
  
end