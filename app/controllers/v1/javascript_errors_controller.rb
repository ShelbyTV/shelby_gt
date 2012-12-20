class V1::JavascriptErrorsController < ApplicationController
  layout false
  
  ##
  # Sends an error to New Relic about a javascript error that occurred in a front end.
  #   AUTHENTICATION IGNORED
  #
  # [POST] /v1/js_err
  #
  # @param [Optional, String] error_message The JS error message from the browser
  # @param [Optional, String] uri The page URI as reported by the browser (window.location.href)
  # @param [Optional, String] client The client generating this error (default: WebFrontEnd) -- Use this to specify TV, staging, etc.
  # @param [Optional, String] * Everything else sent with params will be sent to New Relic as custom params
  def create
    error_msg = params.delete(:error_message) || "(client needs to send 'error_message' parameter)"
    uri = params.delete(:uri) || "(client needs to send 'uri' parameter)"
    client = params.delete(:client) || "WebFrontEnd"
    
    # add some params
    params[:ua] = request.env["HTTP_USER_AGENT"] unless params.include?(:ua)
    
    NewRelic::Agent.notice_error("Javascript error: #{error_msg}", {
      :metric => "Custom/Javascript/#{client}",
      :uri => uri, 
      :custom_params => params})
      
    @status = 200
    render 'v1/blank'
  end
  
end