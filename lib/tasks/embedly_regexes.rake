namespace :embedly_regexes do

  desc 'Update the embedly regexes in our code (run tests and commit afterwards)'
  task :update => :environment do
    require 'fileutils'
    require 'tempfile'

    num_services_inserted = 0
    embedly_ruby_services = []
    # fetch all embedly ruby services
    response = HTTParty.get('http://api.embed.ly/1/services/ruby')
    response.each_with_index do |item, i|
        # keep the info we need for all items that are of type video
        if item["type"] == "video"
          embedly_ruby_services << item.select{|key| ['regex', 'name'].include?(key)}
          num_services_inserted += 1
        end
    end

    # if we got any regexes, update the embedly.yml file with the new regexes
    if num_services_inserted > 0
      settings_file = Rails.root.join('config', 'settings', 'embedly.yml')
      temp_file = Tempfile.new('filename_temp.txt')

      # copy the data from the old file to a temp file,
      # modifying as necessary
      File.open(settings_file, 'r') do |f|
        f.each_line do |line|
          if index = line.index('regexes:')
            # the only line in the file we need to modify is the regexes config
            # have to do some special formatting with gsub to get it into the right format for SettingsLogic's YAML
            temp_file.puts("#{' ' * index}regexes: #{embedly_ruby_services.to_s.gsub(/"(\w+?)"=>/, '\1 : ')}")
          else
            temp_file.puts line
          end
        end
      end
      temp_file.close

      # replace the old file with the new one
      FileUtils.mv(temp_file.path, settings_file)

      Rails.logger.info "Inserted #{num_services_inserted} services"
    end

  end

end
