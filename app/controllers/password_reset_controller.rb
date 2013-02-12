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
  
  # GET /user/password/edit?reset_password_token=3a5ffe7b-f79d-48c6-aadc-2d7d2cd85bba&primary_email=dan@shelby.tv
  def edit
    self.resource = resource_class.new
    resource.reset_password_token = params[:reset_password_token]
    resource.primary_email = params[:primary_email]
  end
  
  # PUT /user/password
  def update
    # Grab user with primary_email (for efficiency) and reset_password_token (for security)
    user = User.where(:primary_email => params[:user][:primary_email], 
                      :reset_password_token => params[:user][:reset_password_token]).first

    if user
      if user.reset_password_period_valid?
        user.reset_password!(params[:user][:password], params[:user][:password])
      else
        user.errors.add(:reset_password_token, :expired)
      end
      
    else
      user = User.new
      user.errors.add(:reset_password_token, :invalid)
    end

    if user.errors.empty?
      # Do the normal sign-in stuff
      GT::UserManager.start_user_sign_in(user)
      sign_in(:user, user)
      set_common_cookie(user, form_authenticity_token)
    end
      
    # success or fail goes to home page
    redirect_to Settings::ShelbyAPI.web_root
  end

end