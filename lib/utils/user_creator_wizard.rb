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
      avatar = ask("Enter the url of the avatar: ") if has_avatar
      has_description = agree("Do you want to enter a description/bio for this user? ") { |q| q.default = "n" }
      dot_tv_description = ask("Enter the user description/bio: ") if has_description
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
        if has_avatar
          @user.user_image_original = avatar
          @user.user_image = avatar
        end
        @user.dot_tv_description = dot_tv_description if has_description
        @user.ensure_authentication_token!
        @user.user_type = User::USER_TYPE[:service] if service_user
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
      has_description = agree("Do you want to enter a description/bio for this user? ") { |q| q.default = "n" }
      dot_tv_description = ask("Enter the user description/bio: ") if has_description

      if user = User.find_by_nickname(nickname)
        user.ensure_authentication_token!
        user.user_type = User::USER_TYPE[:service]
        user.public_roll.roll_type = Roll::TYPES[:special_public_upgraded]
        user.dot_tv_description = dot_tv_description if has_description
        puts "[SUCCESS] #{user.nickname} updated to be a service user."
        if user.public_roll.save and user.save
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

    # add the user's public roll to a roll cateogry in the roll.yml file
    # --parameters--
    # u => A user or an array of users to process
    #
    # --options--
    #
    # :file_name => String --- OPTIONAL the yaml file to modify, roll.yml is the default
    # :category_title => String --- OPTIONAL the roll category to add the roll to, featured is the default
    # :display_thumbnail_src => String --- OPTIONAL an override for the thumbnail image to be associated with the
    # => roll, by default will use the standard helper to determine the user's avatar image
    def self.add_user_to_roll_categories(u, options={})
      u = [u] if !u.is_a?(Array)

      defaults = {
        :file_name => "config/settings/roll.yml",
        :category_title => "Featured",
        :display_thumbnail_src => nil
      }

      options = defaults.merge(options)

      yaml_data = YAML.load_file(options[:file_name])
      category = yaml_data['defaults']['featured'].find{ |c| c['category_title'] == options[:category_title]}

      u.each do |user|
        featured_roll_entry = {
          "display_title" => user.nickname,
          "id" => user.public_roll_id.to_s,
          "display_thumbnail_src" => user.avatar_url,
          "description" => user.dot_tv_description,
          "include_in" => {"onboarding" => true}
        }

        category['rolls'] << featured_roll_entry
      end

      File.open(options[:file_name], 'w') { |f| YAML.dump(yaml_data, f) }
    end
  end
end
