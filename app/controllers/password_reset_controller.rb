class PasswordResetController < Devise::PasswordsController
  
  def new
    super
  end
  
  ##
  # Sends an email with a PW reset token to the specified user
  #
  # [POST] /user/password
  # [GET] /POST/user/password
  # 
  # @param [Required, String] email The primary email address of the user
  def create
    u = User.find_by_primary_email(params[:email])
    if u and u.send_reset_password_instructions
      @status = 200
      @message = "Password reset email sent!"
      render 'v1/blank'
    else
      return render_error(404, "Could not find a user with the email address #{params[:email]}")
    end
  end
  
  # GET /user/password/edit?reset_password_token=abcdef
  def edit
    self.resource = resource_class.new
    resource.reset_password_token = params[:reset_password_token]
  end
  
  # PUT /user/password
  def update
    # b/c password confirmations are dumb (especially when it's so easy to reset)
    params[:user][:password_confirmation] = params[:user][:password]
    self.resource = resource_class.reset_password_by_token(params[resource_name])

    if resource.errors.empty?
      # Do the normal sign-in stuff
      GT::UserManager.start_user_sign_in(resource)
      sign_in(:user, resource)
      set_common_cookie(resource, form_authenticity_token)
      
      # redirect to shelby.tv where they will be logged in
      redirect_to Settings::ShelbyAPI.web_root
    else
      redirect_to Settings::ShelbyAPI.web_root
    end
  end
  
end