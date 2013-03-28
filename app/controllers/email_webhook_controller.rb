require 'json'

class EmailWebhookController < ApplicationController
  def hook
    # don't block the client, just tell it we received the email (status 200)
    # do all the rest of our processing in a non-blocking manner
    ShelbyGT_EM.next_tick {
      mail = Mail.read_from_string(params[:headers])
      if (mail.from)
        mail.from.each do |address|
          # figure out who the email is from and match it up with a shelby user
          if user = User.find_by_primary_email(address)
            # if we've got a user, then parse the email for links
            if (params[:text])
              params[:text].scan(/\b(?:https?:\/\/|www\.)\S+\b/) do |link_match|
                # do something with the links
              end
            end
          end
        end
      end
    }
  end
end
