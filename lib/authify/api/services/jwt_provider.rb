module Authify
  module API
    module Services
      class JWTProvider < Service
        helpers Helpers::APIUser
        
        configure do
          set :protection, except: :http_origin
        end

        before '*' do
          content_type 'application/json'
          headers 'Access-Control-Allow-Origin' => '*',
                  'Access-Control-Allow-Methods' => [
                    'OPTIONS',
                    'GET',
                    'POST'
                  ]

          begin
            unless request.get? || request.options?
              request.body.rewind
              @parsed_body = JSON.parse(request.body.read)
            end
          rescue => e
            halt(400, { :error => "Request must be valid JSON: #{e.message}" }.to_json)
          end
        end

        post '/token' do
          # For CLI / Typical API clients
          access = @parsed_body['access_key']
          secret = @parsed_body['secret_key']
          # For Web UIs
          email = @parsed_body['email']
          password = @parsed_body['password']

          found_user = if access
                         Models::User.from_api_key(access, secret)
                       elsif email
                         Models::User.from_email(email, password)
                       else
                         nil
                       end

          if found_user
            set_current_user found_user
            { jwt: jwt_token }.to_json
          else
            halt 401
          end
        end

        get '/key' do
          content_type 'application/x-pem-file'
          headers["Content-Disposition"] = "attachment;filename=public_key.pem"
          public_key.export
        end
      end
    end
  end
end