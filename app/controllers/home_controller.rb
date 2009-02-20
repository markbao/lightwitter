class HomeController < ApplicationController
	
	def index
		unless logged_in?
			@statuses = nil
		else
			# uses an abstracted oauth_request function to get the statuses.
			@statuses = oauth_request(:get, '/statuses/friends_timeline.json')
			
			# if you want to get the statuses of another user id, try this:
			# user = User.find(12345) --- OR --- user = User.find_by_twitter_name('something')
			# @statuses = oauth_request(:get, 'statuses/friends_timeline.json', user)
		end
	end
	
	def logout
		session[:user_id] = nil
		redirect_to "/home"
	end
	
	def update
		if logged_in?
			# posts an OAuth request with the currently logged in user
			@response = oauth_request(:post, '/statuses/update.json?status=' + CGI::escape(params[:updatetext]))
			
			# this does the same thing as the above, only specifying a user object to use:
			# user = User.find(session[:user_id])
			# @response = oauth_request(:post, '/statuses/update.json?status=' + CGI::escape(params[:updatetext]), user)
			redirect_to "/home"
		end
	end

	def create
    @request_token = get_consumer.get_request_token # calls the OAuth consumer object to get a request token
																										# request token
		
    session[:request_token] = @request_token.token
    session[:request_token_secret] = @request_token.secret		 # save req token and secret so we can validate in callback
    
		# Send to twitter.com to authorize
    redirect_to @request_token.authorize_url									 # get them to the oauth authorize url
	end
	
	# most of this stuff is from http://apiwiki.twitter.com/OAuth+Example+-+Ruby
	
	def callback
		# I didn't abstract this part since we don't have the user data yet.
		
	  @request_token = OAuth::RequestToken.new(get_consumer,
	                                           session[:request_token],
	                                           session[:request_token_secret]) # generate request token using OAuth consumer obj
																																						 # and existing request token, token secret

	  # Exchange the request token for an access token.
	  @access_token = @request_token.get_access_token # access token is the application-user combo auth to twitter

		# do a request using the OAuth consumer, to twitter.com/account/verify_credentials.json
		# USING our access token, so we can GET the data about the user that is described with the access token
	  @response = get_consumer.request(:get, '/account/verify_credentials.json', @access_token, { :scheme => :query_string })		
		
	  case @response
	    when Net::HTTPSuccess
	      user_info = JSON.parse(@response.body) # json parse the response

	      unless user_info['screen_name']
					# for one reason or another -- no screen name was found, auth failed
	        flash[:notice] = "Authentication failed"
	        redirect_to :action => :index
	        return
	      end

	      # We have an authorized user, save the information to the database.
				finduser = User.find_by_twitter_name(user_info['screen_name'])
				if finduser.nil?
					@user = User.create do |u|
						u.twitter_name = user_info['screen_name']
						u.token = @access_token.token
						u.secret = @access_token.secret
					end
					
					@user.save!
				else
					finduser.token = @access_token.token
					finduser.secret = @access_token.secret
					finduser.save!
					
					@user = finduser
				end
	
				session[:user_id] = @user.id

	      # Redirect to the show page
	      redirect_to('/home')
	    else
	      RAILS_DEFAULT_LOGGER.error "Failed to get user info via OAuth"
	      # The user might have rejected this application. Or there was some other error during the request.
	      flash[:notice] = "Authentication failed"
	      redirect_to :action => :index
	  end
	end
end