module Authify
  module API
    module Services
      # The main API Sinatra App
      class API < Service
        use Middleware::JWTAuth
        register Sinatra::JSONAPI

        configure do
          set :protection, except: :http_origin
        end

        # rubocop:disable Metrics/BlockLength
        before '*' do
          headers 'Access-Control-Allow-Origin' => '*',
                  'Access-Control-Allow-Methods' => %w(
                    OPTIONS
                    DELETE
                    GET
                    PATCH
                    POST
                    PUT
                  )

          unless env[:authenticated]
            processed_headers = request.env.dup.each_with_object({}) do |(k, v), acc|
              acc[Regexp.last_match(1).downcase] = v if k =~ /^http_(.*)/i
            end
            if processed_headers.key?('x_authify_access')
              access = processed_headers['x_authify_access']
              secret = processed_headers['x_authify_secret']
              remote_app = Models::TrustedDelegate.from_access_key(access, secret)
              env[:authenticated] = true if remote_app

              if remote_app && processed_headers.key?('x_authify_on_behalf_of')
                @current_user = Models::User.find_by_email(
                  processed_headers['x_authify_on_behalf_of']
                )
              end
            end
          end
          unless env[:authenticated]
            halt 401, env[:authentication_errors].map(&:message).join(', ')
          end
        end

        helpers Helpers::APIUser

        resource :api_keys, &Controllers::APIKey
        resource :groups, &Controllers::Group
        resource :organizations, &Controllers::Organization
        resource :users, &Controllers::User

        freeze_jsonapi
      end
    end
  end
end
