# encoding: utf-8

require 'hashtag_processor'

class EmailWebhookController < ApplicationController
  def hook
    # don't block the client, just tell it we received the email (status 200)
    # do all the rest of our processing in a non-blocking manner
    ShelbyGT_EM.next_tick {
      mail = Mail.read_from_string(params[:headers])
      mail_to = mail.to && mail.to[0]
      p_mail_to = mail_to && mail_to.partition('@')
      valid_mail_to = false
      channel_hastag = nil
      frames_rolled = 0
      # mail to: address must be either "roll" or a channel hashtag at our domain
      # first validate the domain of the address
      if p_mail_to && p_mail_to[2] && (p_mail_to[2].casecmp(Settings::EmailHook.email_hook_domain) == 0)
        email_user = p_mail_to[0]
        # if the user sent to is 'roll', we will roll
        if email_user.casecmp("#{Settings::EmailHook.email_user_keys['roll']}") == 0
          valid_mail_to = true
        elsif channel_hashtag = Settings::Channels.channels.map {|channel| channel['hash_tags']}.flatten.compact.detect {|hashtag| hashtag.casecmp(email_user) == 0}
          valid_mail_to = true
        end
      end
      if valid_mail_to
        if mail.from
          mail.from.each do |address|
            # figure out who the email is from and match it up with a shelby user
            if user = User.find_by_primary_email(address)
              APIClients::KissMetrics.identify_and_record(user, Settings::KissMetrics.metric['hooks']['email_valid_address'])
              # if we've got a user, then parse the email for links
              if (params[:text])
                params[:text].scan(WEB_URL_RE).each_with_index do |link_match, i|
                  # limit the number of links we try to process
                  break if i == Settings::EmailHook.max_rolled_videos
                  # try to create a video for that link
                  if video = GT::VideoManager.get_or_create_videos_for_url(link_match[0])[:videos][0]
                    # if we get a video, make a frame out of it

                    # if the email has a subject, use that as the rolling comment, otherwise
                    # we have a default
                    message_text = (params[:subject] && !params[:subject].empty?) ? params[:subject].clone : Settings::EmailHook.default_rolling_comment.clone
                    # if the email was mailed to a hashtag address, append that hashtag to the rolling message
                    # if the message doesn't already have that tag
                    if channel_hashtag && !message_text.downcase.index('#' + channel_hashtag)
                      message_text << " " if !message_text.match(/\s\z/)
                      message_text << "#" + channel_hashtag
                    end

                    user_public_roll = user.public_roll
                    r = GT::Framer.create_frame({
                      :action => DashboardEntry::ENTRY_TYPE[:new_email_hook_frame],
                      :creator => user,
                      :message => GT::MessageManager.build_message(:user => user, :public => true, :text => message_text),
                      :roll => user_public_roll,
                      :video => video
                    })
                    if r && frame = r[:frame]
                      # keep track of the number of frames rolled
                      frames_rolled += 1
                      # A Frame was rolled, track that user action
                      GT::UserActionManager.frame_rolled!(user.id, frame.id, frame.video_id, frame.roll_id)
                      # Process frame message hashtags
                      GT::HashtagProcessor.process_frame_message_hashtags_for_channels(frame)
                      if user.user_type != User::USER_TYPE[:service]
                        if [Roll::TYPES[:special_public_real_user], Roll::TYPES[:user_public], Roll::TYPES[:global_public]].include?(user_public_roll.roll_type)
                          # if this is a real human shelby user rolling to a public roll,
                          # add the new frame to the community channel in a non-blocking manner
                          frame.add_to_community_channel
                        end
                        # if this is a real human shelby user, send events to Google Analytics to track which
                        # hashtags are being used, in a non-blocking manner
                        GT::HashtagProcessor.process_frame_message_hashtags_send_to_google_analytics(frame)
                      end
                    end
                  end
                end
              end
              # if we rolled any frames for this user, add that to the count of rollings that we will notify the user
              # about the next time they visit the site
              if frames_rolled > 0
                user.rolled_since_last_notification["email"] += frames_rolled
                user.save
                # also track the rolling in kissmetrics
                km_metric = frames_rolled > 1 ? Settings::KissMetrics.metric['roll_frame']['email']['multiple'] : Settings::KissMetrics.metric['roll_frame']['email']['single']
                APIClients::KissMetrics.identify_and_record(user, km_metric)
              end
            else
              APIClients::KissMetrics.identify_and_record('anonymous', Settings::KissMetrics.metric['hooks']['email_invalid_address'])
            end
          end
        end
      end
    }
  end

  private

    WEB_URL_RE = /(?i)\b((?:https?:\/\/|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}\/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:'".,<>?«»“”‘’]))/

end
