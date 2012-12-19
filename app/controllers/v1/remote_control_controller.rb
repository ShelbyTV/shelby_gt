class V1::RemoteControlController < ApplicationController

  def show

  end

  ################
  # The :id is the code gotten from calling remote_control#create
  #  REQUIRED :
  #    params[:command] is the command to send from the remote to the screen
  #  OPTIONAL :
  #    params[:data] can be data passed to the screen from the remote (for searching?)
  def update
    if rc = RemoteControl.where(:code => params[:id]).all
      rc.keep_if {|r| r.code == params[:id] }
      @remote_control = rc.first
      @command = params[:command]
      @data = params[:data]
      ShelbyGT_EM.next_tick do
        pusher_client.trigger('remote-'+@remote_control.code, @command, @data)
      end
      @status = 200
    else
      render_error(404, "could not find a remote control with that id. :<>")
    end
  end

  def create
    if @remote_control = RemoteControl.create()
      @status = 200
    else
      render_error(404, "could not create the remote control code :/")
    end
  end

  private
    def pusher_client
      unless @pusher_client
        @pusher_client = ::Pusher::Client.new({
          app_id: Settings::Pusher.id,
          key: Settings::Pusher.key,
          secret: Settings::Pusher.secret
        })
      end
      @pusher_client
    end

end
