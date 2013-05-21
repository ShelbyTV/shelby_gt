require "highline/import"
require 'user_manager'

module Dev
  class Wizard

    def self.create_user!

      nickname = ask('Enter a username: ') do |q|
        q.validate = lambda { |a| a.length > 0 }
        q.responses[:not_valid] = "You didn't enter a username. Try again please."
      end
      password = ask("Enter a password: ") { |q| q.echo = "x" }
      email = ask("Enter an email address for the user: ")
      name = ask("Enter the name of the user: ")
      has_avatar = agree("Do you have an avatar for this user? ") { |q| q.default = "n" }
      avatar = ask("enter the url of the avatar: ") if has_avatar
      youtube_user = agree('Will this be a youtube BotRoll user? ') { |q| q.default = "n"}
      if youtube_user
        service_user = true
        youtube_username = ask('Enter a youtube username: ') do |q|
          q.validate = lambda { |a| a.length > 0 }
          q.responses[:not_valid] = "You didn't enter a username. Try again please."
        end
      else
        service_user = agree("Is the user a 'service' user? ") { |q| q.default = "y" }
      end

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
        @user.user_type = 3 if service_user
        if @user.save
          puts "[SUCCESS] #{@user.name} created: \n #{@user.inspect}"
          if youtube_user
            puts "[WORKING] Configuring youtube BotRoll via audrey2"
            begin
              response = HTTParty.post("#{Settings::Audrey2.api_url}/v1/feeds", {:body =>
                {
                  :type => 'youtube',
                  :id => youtube_username,
                  :auth_token => @user.authentication_token,
                  :roll_id => @user.public_roll_id.to_s
                }
              })
            rescue Exception => e
              puts "[FAILURE] audrey2 request failed: \n #{e.inspect}"
              return
            end
            if response.code == 200
              puts "[SUCCESS] audrey2 API responded with: \n #{response.code} -- #{response.body}"
            else
              puts "[FAILURE] audrey2 API responded with: \n #{response.code} -- #{response.body}"
            end
          end
        else
          puts "[FAILURE] Something went horribly wrong: #{@user.errors.messages}"
        end
      else
        puts "[FAILURE] Something went horribly wrong: #{@user.errors.messages}"
      end
    end

    def self.add_botroll_to_user!
      nickname = ask('Enter a username: ') do |q|
        q.validate = lambda { |a| a.length > 0 }
        q.responses[:not_valid] = "You didn't enter a username. Try again please."
      end

      if user = User.find_by_nickname(nickname)
        user.ensure_authentication_token!
        user.user_type = 3
        puts "[SUCCESS] #{user.nickname} updated to be a service user."
        if user.save
          youtube_username = ask('Enter a youtube username: ') do |q|
            q.validate = lambda { |a| a.length > 0 }
            q.responses[:not_valid] = "You didn't enter a username. Try again please."
          end

          puts "[WORKING] Configuring youtube BotRoll via audrey2"
          begin
            response = HTTParty.post("#{Settings::Audrey2.api_url}/v1/feeds", {:body =>
              {
                :type => 'youtube',
                :id => youtube_username,
                :auth_token => user.authentication_token,
                :roll_id => user.public_roll_id.to_s
              }
            })
          rescue Exception => e
            puts "[FAILURE] audrey2 request failed: \n #{e.inspect}"
            return
          end
          if response.code == 200
            puts "[SUCCESS] audrey2 API responded with: \n #{response.code} -- #{response.body}"
          else
            puts "[FAILURE] audrey2 API responded with: \n #{response.code} -- #{response.body}"
          end

        else
          puts "[FAILURE] Something went horribly wrong: #{user.errors.messages}"
        end
      else
        puts "[FAILURE] Could't find any user with that nickname"
      end
    end

  end
end
