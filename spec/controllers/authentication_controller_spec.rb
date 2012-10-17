require 'spec_helper'
require 'api_clients/sailthru_client'

describe AuthenticationsController do

  context "POST login" do
    before(:each) do
      @u = Factory.create(:user)
      @u.password = (@password = "password")
      @u.save
    end
    
    context "success" do
      before(:each) do
        #make sure all methods below end up with a successful sign in
        AuthenticationsController.any_instance.stub(:sign_in).with(:user, @u)
        
        # no need to hit the Internet
        GT::UserManager.stub(:start_user_sign_in)
      end
      
      it "should login user via email" do
        post :login, :username => @u.primary_email, :password => @password
      end

      it "should login user via username" do
        post :login, :username => @u.nickname, :password => @password
      end

      it "should set common cookie on login" do
        post :login, :username => @u.nickname, :password => @password
        cookies[:_shelby_gt_common].should_not == nil
      end

      it "should send user to root of web app on login" do
        post :login, :username => @u.nickname, :password => @password
        assigns(:opener_location).should == Settings::ShelbyAPI.web_root
      end

      it "should honor session based redirects on login" do
        session[:return_url] = (url = "http://danspinosa.tv")
        post :login, :username => @u.nickname, :password => @password
        assigns(:opener_location).should == url
      end
      
      it "should handle redirect via redir query param" do
        post :login, :redir => "localhost", :username => @u.nickname, :password => @password
        assigns(:opener_location).should == "localhost"
      end
    end

    context "fail" do
      it "should redirect back to the submitting page on error" do
        request.stub(:referer).and_return(referer="http://whatever.com/")
        post :login
        response.redirect_url.should match /#{referer}.*/
      end
      
      it "should redirect to API root when referer is missing" do
        request.stub(:referer).and_return nil
        post :login
        response.redirect_url.should match /#{Settings::ShelbyAPI.web_root}.*/
      end
      
      it "should return proper error when username is missing" do
        post :login, :password => @password
        response.redirect_url.should match /.*auth_failure=1.*/
      end
      
      it "should return proper error when password is missing" do
        post :login, :username => @u.nickname
        response.redirect_url.should match /.*auth_failure=1.*/
      end
      
      it "should return proper error on username/email has no match" do
        post :login, :username => "asdflio24523ln", :password => @password
        response.redirect_url.should match /.*auth_failure=1.*/
      end

      it "should return proper error on password incorrect" do
        post :login, :username => @u.nickname, :password => @password+"X"
        response.redirect_url.should match /.*auth_failure=1.*/
      end
      
      it "should preserve redirect on error" do
        post :login, :redir => "localhost"
        response.redirect_url.should match /.*auth_failure=1.*/
        response.redirect_url.should match /.*redir=localhost.*/
      end
    end
  
  end
    
  context "Current user merging in another account" do
    before(:each) do
      # Setup and sign in a user
      @into_user = Factory.create(:user)
      AuthenticationsController.any_instance.stub(:current_user).and_return(@into_user)
      AuthenticationsController.any_instance.stub(:authenticate_user!).and_return(true)
      
      # Have omniauth stuff return another one
      request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}}) #so that we look for a User
      @other_user = Factory.create(:user) #returned as if it was found via omniauth
      User.stub(:first).and_return(@other_user)
    end

    context "create (merge via omniauth)" do
      it "should put the omniauth'd user's id into the session" do
        get :create
      
        session[:user_to_merge_in_id].should == @other_user.id.to_s
      end

      it "should route to should_merge_accounts path when a current user authenticates a different user via omniauth" do
        get :create
      
        assigns(:opener_location).should == should_merge_accounts_authentications_path
      end
    end
    
    context "should_merge_accounts" do
      it "should set other_user via the id stored in the session" do
        session[:user_to_merge_in_id] = @other_user.id.to_s

        get :should_merge_accounts

        assigns(:other_user).should == @other_user
      end

      it "should set into_user as the currently signed in user" do
        get :should_merge_accounts
        
        assigns(:into_user).should == @into_user
      end
      
      it "should sign user out if other_user cannot be found" do
        session[:user_to_merge_in_id] = "some_crap"

        get :should_merge_accounts
        
        response.should redirect_to(sign_out_user_path)
      end
    end
    
    context "POST do_merge_accounts" do
      before(:each) do
        session[:user_to_merge_in_id] = @other_user.id.to_s
      end
      
      it "should merge the user from the session into the current user" do
        GT::UserMerger.should_receive(:merge_users).with(@other_user, @into_user).exactly(1).times.and_return(true)
        post :do_merge_accounts
      end
      
      it "should redirect to web root on successfull merge" do
        GT::UserMerger.should_receive(:merge_users).with(@other_user, @into_user).and_return(true)
        post :do_merge_accounts
        
        assigns(:opener_location).should == Settings::ShelbyAPI.web_root
      end
      
      it "should sign the user out if there is no user to merge in in the session" do
        session[:user_to_merge_in_id] = nil
        GT::UserMerger.should_receive(:merge_users).with(@other_user, @into_user).exactly(0).times
        post :do_merge_accounts
        
        assigns(:opener_location).should == sign_out_user_path
      end
    end
  
  end
    
  context "with faked sign_in and current_user" do
    # We're not trying to test Devise here, so just set current_user as expected when they get signed in...
    controller(AuthenticationsController) do
      def sign_in(resource_or_scope, resource=nil) @current_user = resource; end
      def current_user() @current_user; end
    end

    context "gt_enabled, non-faux user, just signing in" do
      context "via omniauth" do
        before(:each) do
          request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
          @u = Factory.create(:user, :gt_enabled => true, :faux => User::FAUX_STATUS[:false], :cohorts => ["init"])
          User.stub(:first).and_return(@u)
      
          GT::UserManager.should_receive :start_user_sign_in
        end
    
        it "should simply sign the user in" do
          get :create
          assigns(:current_user).should == @u
          cookies[:_shelby_gt_common].should_not == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        end
      
        it "should add cohorts if they used a CohortEntrance link" do
          cohorts = ["a", "b", "c", "post_onboarding"]
          expected_cohorts = @u.cohorts + cohorts
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
        
          get :create
          assigns(:current_user).cohorts.should == expected_cohorts
          @u.reload.cohorts.should == expected_cohorts
          session[:cohort_entrance_id].should == nil
        end
        
        it "should gt_enable a user coming in via a cohort link" do
          @u.gt_enabled = false; @u.save
          cohorts = ["post_onboarding"]
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
        
          get :create          
          assigns(:current_user).gt_enabled.should == true
        end
    
        it "should handle redirect via session on sign in" do
          session[:return_url] = (url = "http://danspinosa.tv")
          get :create
          assigns(:opener_location).should == url
        end
    
        it "should handle redirect via omniauth on sign in" do
          request.env['omniauth.origin'] = (url = "http://danspinosa.tv")
          get :create
          assigns(:opener_location).should == url
        end

      end

    end
  
    context "Adding new authentication to current user" do
      before(:each) do
        request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
        User.stub(:first).and_return(nil)
      
        @u = Factory.create(:user, :gt_enabled => true)
        controller.stub(:current_user).and_return(@u)
      end

      it "should add the new auth" do
        GT::UserManager.should_receive(:add_new_auth_from_omniauth).and_return true
      
        get :create
        assigns(:opener_location).should == Settings::ShelbyAPI.web_root
      end
    
      it "should be able to redirect after adding the new auth" do
        GT::UserManager.should_receive(:add_new_auth_from_omniauth).and_return true
      
        session[:return_url] = (url = "http://danspinosa.tv")
        get :create
        assigns(:opener_location).should == url
      end
    
      it "should not save twitter autocomplete since this is not a signin" do
          GT::UserManager.should_receive(:add_new_auth_from_omniauth).and_return true
          APIClients::TwitterInfoGetter.should_not_receive(:new)

          get :create
      end

    end
  
    context "New User signing up" do
      context "no permissions" do
        before(:each) do
          request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
          User.stub(:first).and_return(nil)
        end

        it "should reject without additional permissions" do
          APIClients::TwitterInfoGetter.should_not_receive(:new)
          get :create
          assigns(:opener_location).should == "#{Settings::ShelbyAPI.web_root}?access=nos"
        end
      end
    
      context "via omniauth" do    
        before(:each) do
          request.stub!(:env).and_return({"omniauth.auth" => {'provider'=>'twitter'}})
          @u = Factory.create(:user)
          GT::UserManager.should_receive(:create_new_user_from_omniauth).and_return(@u)
        end

        it "should accept when GtInterest found" do
          gt_interest = Factory.create(:gt_interest)
          cookies[:gt_access_token] = {:value => gt_interest.id.to_s, :domain => ".shelby.tv"}

          get :create
          assigns(:current_user).should == @u
          assigns(:current_user).gt_enabled.should == true
          cookies[:_shelby_gt_common].should_not == nil
          cookies[:gt_access_token].should == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        end
    
        it "should be able to redirect when GtInterest found" do
          gt_interest = Factory.create(:gt_interest)
          cookies[:gt_access_token] = gt_interest.id.to_s
      
          session[:return_url] = (url = "http://danspinosa.tv")
          get :create
          assigns(:opener_location).should == url
        end
        
        it "should accept with CohortEntrance, set cohorts" do
          cohorts = ["a", "b", "c"]
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
          
          get :create
          assigns(:current_user).should == @u
          assigns(:current_user).gt_enabled.should == true
          cookies[:_shelby_gt_common].should_not == nil
          session[:cohort_entrance_id].should == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        
          assigns(:current_user).cohorts.should == cohorts
          @u.reload.cohorts.should == cohorts
        end
      end
    
      context "via email / password" do
        it "should accept with CohortEntrance, set cohorts" do
          cohorts = ["a", "b", "c", "post_onboarding"]
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
        
          u = Factory.create(:user, :password => (password="pass"), :gt_enabled => true, :faux => User::FAUX_STATUS[:false], :cohorts => [], :authentications => [])
          GT::UserManager.should_receive(:create_new_user_from_params).and_return u
          APIClients::TwitterInfoGetter.should_not_receive(:new)
          get :create, :user => {:some_params => :needed, :but_its => :stubbed_anyway}
      
          assigns(:current_user).should == u
          assigns(:current_user).gt_enabled.should == true
          cookies[:_shelby_gt_common].should_not == nil
          session[:cohort_entrance_id].should == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        
          assigns(:current_user).cohorts.should == cohorts
          u.reload.cohorts.should == cohorts
        end
        
        it "should redirect to cohort entrance, with errors, when user creation fails" do
          cohorts = ["a", "b", "c"]
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
        
          u = Factory.create(:user, :password => (password="pass"), :gt_enabled => true, :faux => User::FAUX_STATUS[:false], :cohorts => [])
          u2 = User.new(:nickname => u.nickname)
          u2.save
          u2.valid?.should == false
          GT::UserManager.should_receive(:create_new_user_from_params).and_return u2
          APIClients::TwitterInfoGetter.should_not_receive(:new)
          get :create, :user => {:some_params => :needed, :but_its => :stubbed_anyway}
          
          assigns(:current_user).should == nil
          assigns(:opener_location).start_with?(cohort_entrance.url+"?").should == true
        end
                
      end
    
    end


    context "faux user" do
      context "no permissions" do

        it "should reject without additional permissions" do
          APIClients::TwitterInfoGetter.should_not_receive(:new)
          get :create
          assigns(:current_user).should == nil
        end

      end

      context "via omniauth" do
        before(:each) do
          request.stub!(:env).and_return({"omniauth.auth" =>
            {
              'provider'=>'twitter',
              'credentials'=>{'token'=>nil, 'secret'=>nil}
            }})
          @u = Factory.create(:user, :gt_enabled => false, :faux => User::FAUX_STATUS[:true], :cohorts => ["init"])
          User.stub(:first).and_return(@u)
        end
      
        it "should accept and convert if gt_enabled" do
          @u.gt_enabled = true
          @u.save
          
          GT::UserManager.should_receive :convert_faux_user_to_real
          GT::UserManager.should_receive :start_user_sign_in

          get :create
          assigns(:current_user).should == @u
          assigns(:current_user).gt_enabled.should == true
          cookies[:_shelby_gt_common].should_not == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        end
      
        it "should accept and convert if GtInterest found" do
          gt_interest = Factory.create(:gt_interest)
          cookies[:gt_access_token] = {:value => gt_interest.id.to_s, :domain => ".shelby.tv"}

          GT::UserManager.should_receive :convert_faux_user_to_real
          GT::UserManager.should_receive :start_user_sign_in

          get :create
          assigns(:current_user).should == @u
          cookies[:_shelby_gt_common].should_not == nil
          cookies[:gt_access_token].should == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root
        end
      
        it "should be able to redirect on GtInterest" do
          gt_interest = Factory.create(:gt_interest)
          cookies[:gt_access_token] = gt_interest.id.to_s

          GT::UserManager.should_receive :convert_faux_user_to_real
          GT::UserManager.should_receive :start_user_sign_in

          session[:return_url] = (url = "http://danspinosa.tv")
          get :create
          assigns(:opener_location).should == url
        end
        
        it "should accept and convert with CohortEntrance, set cohorts on user" do
          cohorts = ["a", "b", "c"]
          expected_cohorts = @u.cohorts + cohorts << "post_onboarding"
          cohort_entrance = Factory.create(:cohort_entrance, :cohorts => cohorts)
          session[:cohort_entrance_id] = cohort_entrance.id
          
          GT::UserManager.should_receive :convert_faux_user_to_real
          GT::UserManager.should_receive :start_user_sign_in
          
          get :create
          assigns(:current_user).should == @u
          cookies[:_shelby_gt_common].should_not == nil
          assigns(:opener_location).should == Settings::ShelbyAPI.web_root

          assigns(:current_user).cohorts.should == expected_cohorts
          @u.reload.cohorts.should == expected_cohorts
        end
      end
    end

  end

  context "Create" do
    before(:each) do
      request.stub!(:env).and_return({"omniauth.auth" => {}})
      @u1 = Factory.create(:user, :gt_enabled => false)
      User.stub(:first).and_return(@u1)
      
      AuthenticationsController.any_instance.stub(:current_user).and_return(nil)
    end

    it "should remove previous auth failure params from the query string for redirect" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?auth_failure=1&auth_strategy=Facebook&param1=val1&param2=val2'})  
      controller.should_receive(:redirect_path).and_return('http://www.example.com?param1=val1&param2=val2')
      get :create, :provider => "Twitter"
    end

    it "should have no ? if the query string is empty after removing the auth failure params" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?auth_failure=1&auth_strategy=Facebook'})  
      controller.should_receive(:redirect_path).and_return('http://www.example.com')
      get :create, :provider => "Twitter"
    end
  end

  context "Auth failure" do

    it "should add failure param to root url on auth failure" do
      get :fail
      assigns(:opener_location).should eq(Settings::ShelbyAPI.web_root + '?auth_failure=1')
    end

    it "should add failure param and strategy param to root url on auth failure when strategy specified" do
      get :fail, :strategy => 'Facebook'
      assigns(:opener_location).should eq(Settings::ShelbyAPI.web_root + '?auth_failure=1&auth_strategy=Facebook')
    end

    it "should add failure param to session return url on auth failure" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?param1=val1&param2=val2'})
      get :fail
      assigns(:opener_location).should eq('http://www.example.com?auth_failure=1&param1=val1&param2=val2')
    end

    it "should add failure param and strategy param to session return url on auth failure when strategy specified" do
      controller.stub!(:session).and_return({:return_url => 'http://www.example.com?param1=val1&param2=val2'})
      get :fail, :strategy => 'Facebook'
      assigns(:opener_location).should eq('http://www.example.com?auth_failure=1&auth_strategy=Facebook&param1=val1&param2=val2')
    end

  end
  
  context "Signout" do
    it "should redirect to web root when referer is missing" do
      # request.stub(:referer).and_return nil
      get :sign_out_user
      response.redirect_url.should match /#{Settings::ShelbyAPI.web_root}.*/
    end

    it "should redirect to the referer if the referer has no path" do
      request.stub(:referer).and_return("http://whatever.com/")
      get :sign_out_user
      response.redirect_url.should match /http:\/\/whatever\.com\/?/
    end

    it "should redirect to the root of the referer if the referer has a path or query" do
      request.stub(:referer).and_return("http://whatever.com/path/page.html?param1=1")
      get :sign_out_user
      response.redirect_url.should match /http:\/\/whatever\.com\/?/
    end
  end

end

