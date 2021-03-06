module Authify
  module API
    module Helpers
      # Helper methods for working with JWT encryption
      module JWTEncryption
        include Core::Helpers::JWTSSL

        def jwt_token(user: nil, custom_data: {}, meta: nil)
          user ||= current_user
          JWT.encode jwt_payload(user, custom_data, meta), private_key, CONFIG[:jwt][:algorithm]
        end

        # rubocop:disable Metrics/AbcSize
        def jwt_payload(user, custom_data, metadata = nil)
          data = {
            exp: Time.now.to_i + 60 * CONFIG[:jwt][:expiration].to_i,
            iat: Time.now.to_i,
            iss: CONFIG[:jwt][:issuer],
            scopes: Core::Constants::JWTSCOPES.dup.tap do |scopes|
              scopes << :admin_access if user.admin?
            end,
            user: {
              username: user.email,
              uid: user.id,
              organizations: simple_orgs_by_user(user)
            }
          }
          data[:custom] = custom_data if custom_data && !custom_data.empty?
          data[:meta] = metadata if metadata && metadata.is_a?(Hash) && !metadata.empty?
          data
        end

        def jwt_options
          {
            algorithm: CONFIG[:jwt][:algorithm],
            verify_iss: true,
            verify_iat: true,
            iss: CONFIG[:jwt][:issuer]
          }
        end

        def process_token(token)
          results = {}

          begin
            decoded = JWT.decode(token, public_key, true, jwt_options)

            results[:valid] = true
            results[:payload] = decoded[0]
            results[:type] = decoded[1]['typ']
            results[:algorithm] = decoded[1]['alg']
          rescue JWT::DecodeError => e
            results[:valid] = false
            results[:errors] = Array[e]
            results[:reason] = 'Corrupt or invalid JWT'
          end
          results
        end

        def simple_orgs_by_user(user)
          user.organizations.map do |o|
            {
              name: o.name,
              oid: o.id,
              admin: o.admins.include?(user),
              memberships: o.groups.select { |g| g.users.include?(user) }.map do |g|
                { name: g.name, gid: g.id }
              end
            }
          end
        end

        def with_jwt(req, scope)
          scopes, user = req.env.values_at :scopes, :user
          set_current_user Models::User.from_username(user['username'])

          if scopes.include?(scope) && current_user
            yield req
          else
            halt 403
          end
        end
      end
    end
  end
end
