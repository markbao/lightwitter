# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

	helper_method :current_user, :logged_in?, :get_consumer, :access_token, :oauth_request
	
  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery # :secret => 'ec05277619839050aa60b161bb3ab98c'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password").
  # filter_parameter_logging :password

	def current_user
		@current_user ||= ((session[:user_id] && User.find_by_id(session[:user_id])) || 0)
	end
	
	def logged_in?()
		current_user != 0
	end
	
	# get_consumer establishes a OAuth consumer object
	def get_consumer
		# consumer key, consumer secret
		OAuth::Consumer.new("cuYChiPyQA9AwITpvz3TsA",
												"Q40xOUxQS5JUhh6oQPyFDfyCVWOuaQvFOQtwHRiGNA",
												{ :site=>"http://twitter.com" })
	end
	
	# access_token establishes an access token, given either that a user is logged in, or a user object is specified
	def access_token(user = nil)
		if user.nil?
			if logged_in?
				OAuth::AccessToken.new(get_consumer, current_user.token, current_user.secret)
			end
		else
			# you can specify your own user object
			OAuth::AccessToken.new(get_consumer, user.token, user.secret)
		end
	end
	
	# oauth_request establishes an oauth request, given a method and an api endpoint
	def oauth_request(method, url, user = nil)
		if user.nil?
			# custom user object wasn't specified, use currently logged in user
			if logged_in?
				response = get_consumer.request(method, url, access_token, { :scheme => :query_string })
			end
		else
			response = get_consumer.request(method, url, access_token(user), { :scheme => :query_string })
		end
		
		case response
			when Net::HTTPSuccess
				return JSON.parse(response.body)
			else
				RAILS_DEFAULT_LOGGER.error "Failed to get friend timeline via OAuth for #{current_user}"
				return false
		end # ends case response
	end
	
end
