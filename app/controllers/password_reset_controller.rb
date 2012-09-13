class PasswordResetController < Devise::PasswordsController
  
  # GET /user/password/new
  def new
    super
  end
  
  # POST /user/password
  def create
    self.resource = resource_class.send_reset_password_instructions(params[resource_name])

    unless successfully_sent?(resource)
      flash[:notice] = "Could not find a user with that email address."
      redirect_to new_user_password_path
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