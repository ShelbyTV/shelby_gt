require 'spec_helper'

describe NotificationMailer do
  describe 'comment notifications' do
    before(:all) do
      @user_to = Factory.create(:user)
      @user_from = Factory.create(:user)
      @comment = "how much would a wood chuck chuck..."
      @message = Factory.create(:message, :text => @comment, :user => @user_to)
      @conversation = Factory.create(:conversation, :messages => [@message])
      @video = Factory.create(:video, :title => 'tit')
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :roll=> @roll, :video => @video)
      @email = NotificationMailer.comment_notification(@user_to, @user_from, @frame, @message)
    end

    it 'renders the subject' do
      @email.subject.should_not == nil
    end

    it 'renders the receiver email' do
      @email.to.should eq([@user_to.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end

    it 'should contain a link to the frame comments' do
      @email.body.encoded.should match("#{Settings::ShelbyAPI.web_root}/roll/#{@roll.id}/frame/#{@frame.id}/comments")
    end

    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end

  describe 'upvote notifications' do
    before(:all) do
      @user_to = Factory.create(:user, :primary_email => 'your@mom.com')
      @user_from = Factory.create(:user, :primary_email => 'my@mom.com')
      @video = Factory.create(:video, :title => 'ti')
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :video => @video, :roll => @roll)
      @email = NotificationMailer.upvote_notification(@user_to, @user_from, @frame)
    end

    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.upvote_notification['subject'] % {:upvoters_name => @user_from.nickname, :video_title => 'ti' } )
    end

    it 'renders the receiver email' do
      @email.to.should eq([@user_to.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end

    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end

  describe 'disqus comment notifications' do
    before(:all) do
      @user_to = Factory.create(:user)
      @video = Factory.create(:video, :title => 'ti')
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :video => @video, :roll => @roll, :creator=>@user_to)
      @email = NotificationMailer.disqus_comment_notification(@frame, @user_to)
    end

    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.disqus_comment_notification['subject'])
    end

    it 'renders the receiver email' do
      @email.to.should eq([@user_to.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end
  end

  describe 'like notifications' do
    before(:all) do
      @user_to = Factory.create(:user)
      @user_from = Factory.create(:user)
      @video = Factory.create(:video, :title => 'ti')
      @roll = Factory.create(:roll, :creator => @user_to)
      @frame = Factory.create(:frame, :video => @video, :roll => @roll, :creator => @user_from)
    end

    context "shelby user liker" do
      before(:all) do
        @email = NotificationMailer.like_notification(@user_to, @frame, @user_from)
      end

      it 'renders the subject' do
        @email.subject.should eq(Settings::Email.like_notification['subject'] % {:likers_name => @user_from.nickname, :video_title => @frame.video.title } )
      end

      it 'renders the receiver email' do
        @email.to.should eq([@user_to.primary_email])
      end

      it 'renders the sender email' do
        @email.from.should eq([Settings::Email.notification_sender])
      end

      it 'should have a link to the sending user' do
        @email.body.encoded.should have_tag(:a, :with => { :href => "#{Settings::Email.web_url_base}/#{@user_from.id.to_s}" })
      end
    end

    context "anonymous liker" do
      before(:all) do
        @email = NotificationMailer.like_notification(@user_to, @frame)
      end

      it 'renders the subject' do
        @email.subject.should eq(Settings::Email.like_notification['subject'] % {:likers_name => 'Someone', :video_title => @frame.video.title} )
      end

      it 'renders the receiver email' do
        @email.to.should eq([@user_to.primary_email])
      end

      it 'renders the sender email' do
        @email.from.should eq([Settings::Email.notification_sender])
      end

      it 'should not have a link to a sending user' do
        @email.body.encoded.should_not have_tag(:a, :with => { :href => "#{Settings::Email.web_url_base}/#{@user_from.nickname}" })
      end

      it 'should contain the like message' do
        @email.body.encoded.should match(@frame.video.title)
      end
    end
  end

  describe 'reroll notifications' do
    before(:all) do
      @old_user = Factory.create(:user)
      @new_user = Factory.create(:user)
      @old_roll = Factory.create(:roll, :creator => @old_user)
      @new_roll = Factory.create(:roll, :creator => @new_user)
      @video = Factory.create(:video, :title => 'tit')
      @old_frame = Factory.create(:frame, :creator => @old_user, :video => @video, :roll => @old_roll)
      @new_frame = Factory.create(:frame, :creator => @new_user, :video => @video, :roll => @new_roll)
      @email = NotificationMailer.reroll_notification(@old_frame, @new_frame)
    end

    it 'renders the subject' do
      @email.subject.should eq(Settings::Email.reroll_notification['subject'] % {:re_rollers_name => @new_user.nickname, :video_title => 'tit'})
    end

    it 'renders the receiver email' do
      @email.to.should eq([@old_user.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end

    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end

  describe 'join roll notifications' do
    before(:all) do
      @user_joined = Factory.create(:user, :name => "dan")
      @roll_owner = Factory.create(:user)
      @roll = Factory.create(:roll, :creator => @roll_owner, :public => false, :title => "tit")
      @video = Factory.create(:video)
      @email = NotificationMailer.join_roll_notification(@roll_owner, @user_joined, @roll)
    end

    it 'renders the subject' do
      subj = Settings::Email.join_roll_notification['subject'] % {:users_name =>"dan", :roll_title => "tit"}
      @email.subject.should eq(subj)
    end

    it 'renders the receiver email' do
      @email.to.should eq([@roll_owner.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end

    #ensure that the an instance var is assigned properly, eg @confirmation_url variable appears in the email body
    #it 'assigns @confirmation_url' do
    #  mail.body.encoded.should match("http://aplication_url/#{user.id}/confirmation")
    #end
  end

  describe 'invite accepted notifications' do
    before(:all) do
      @inviter = Factory.create(:user)
      @invitee = Factory.create(:user, :name => "bill")
      @invitee_personal_roll = Factory.create(:roll, :creator => @invitee, :public => false, :title => "tit")
      # @video = Factory.create(:video)
      @email = NotificationMailer.invite_accepted_notification(@inviter, @invitee, @invitee_personal_roll)
    end

    it 'renders the subject' do
      subj = Settings::Email.invite_accepted_notification['subject'] % {:users_name =>"bill"}
      @email.subject.should eq(subj)
    end

    it 'renders the receiver email' do
      @email.to.should eq([@inviter.primary_email])
    end

    it 'renders the sender email' do
      @email.from.should eq([Settings::Email.notification_sender])
    end
  end

  describe 'weekly recommendation' do
    before(:all) do
      @user = Factory.create(:user)
      @sharer = Factory.create(:user)
      @video = Factory.create(:video)
      @frame = Factory.create(:frame, :creator => @sharer, :video => @video)
      @dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation], :frame => @frame, :video => @video)
    end

    it 'renders the subjects' do
      @email = NotificationMailer.weekly_recommendation(@user, [@dbe, @dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, from us to you. Enjoy!")

      @email = NotificationMailer.weekly_recommendation(@user, [@dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, this video was shared by #{@sharer.nickname}. Check it out.")

      @frame.frame_type = Frame::FRAME_TYPE[:light_weight]
      @email = NotificationMailer.weekly_recommendation(@user, [@dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, this video was liked by #{@sharer.nickname}. Check it out.")

      mortar_src_video = Factory.create(:video)
      recommended_video = Factory.create(:video)
      frame = Factory.create(:frame, :video => recommended_video)
      mortar_dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation], :frame => frame, :src_video => mortar_src_video)

      @email = NotificationMailer.weekly_recommendation(@user, [mortar_dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, a video because you liked: \"#{mortar_src_video.title}\"")

      src_frame = Factory.create(:frame, :creator => @sharer)
      video_graph_dbe = Factory.create(:dashboard_entry, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], :frame => frame, :src_frame => src_frame)

      @email = NotificationMailer.weekly_recommendation(@user, [video_graph_dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, watch this, it's similar to videos #{@sharer.nickname} has shared")

      src_frame.frame_type = Frame::FRAME_TYPE[:light_weight]
      @email = NotificationMailer.weekly_recommendation(@user, [video_graph_dbe])
      @email.subject.should eq("#{@user.nickname.titlecase}, watch this, it's similar to videos #{@sharer.nickname} has liked")
    end

    it 'renders the receiver email' do
      @email = NotificationMailer.weekly_recommendation(@user, [@dbe])
      @email.to.should eq([@user.primary_email])
    end

    it 'renders the sender email' do
      @email = NotificationMailer.weekly_recommendation(@user, [@dbe])
      @email.from.should eq([Settings::Email.notification_sender])
    end
  end

end
