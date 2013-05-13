require "highline/import"
require 'user_manager'

module Dev
  class Wizard

    def self.create_user!

      nickname = ask('Enter a username: ')
      password = ask("Enter a password:  ") { |q| q.echo = "x" }
      email = ask("Enter an email address for the user: ")
      name = ask("Enter the name of the user: ")
      has_avatar = ask("Do you have an avatar for this user? ") { |q| q.default = "yes" }
      avatar = ask("enter the url of the avatar: ") if has_avatar == "yes"
      service_user = ask("Is the user a 'service' user? ") { |q| q.default = "yes" }

      user_params = {
        nickname: nickname,
        primary_email: email,
        password: password,
        name: name
      }

      @user = GT::UserManager.create_new_user_from_params(user_params)
      if @user and @user.errors.empty? and @user.valid?
        @user.user_image = avatar if has_avatar
        @user.ensure_authentication_token!
        @user.user_type = 3 if service_user.downcase == "yes"
        puts "[SUCCESS] #{@user.name} created: \n #{@user.inspect}" if @user.save
      else
        puts "[FAILURE] Something went horribly wrong: #{@user.errors}"
      end
    end

  end
end
