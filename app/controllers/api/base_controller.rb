module Api
    class BaseController < ApplicationController
      #skip_before_action :authenticate_user! #todo
      skip_before_action :verify_authenticity_token
      before_action :authenticate_with_api_key
   
      attr_reader :current_bearer, :current_api_key
   
      protected
      
   
      def authenticate_with_api_key
        if request.params[:token].present? #authenticate with token in params
          return true if api_key?(request.params[:token])
          request_http_token_authentication
          return
        end
        
        authenticate_or_request_with_http_token do |token, options|
          token = request.params[:token] unless params[:token].blank?
          api_key?(token)
        end
      end
      
   
      # Override rails default 401 response to return JSON content-type
      # with request for Bearer token
      # https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token/ControllerMethods.html
      def request_http_token_authentication(realm = "Application", message = nil)
        json_response = { errors: [message || "Access denied"] }
        headers["WWW-Authenticate"] = %(Bearer realm="#{realm.tr('"', "")}")
        render json: json_response, status: :unauthorized
      end
  
  
      private 
  
      def api_key?(token)
        @current_api_key = ApiKey
          .where(revoked_at: nil)
          .where("expires_at is NULL OR expires_at > ?", Time.zone.now)
          .find_by_token(token)
        @current_bearer = current_api_key&.bearer
      end
  
    end
  end