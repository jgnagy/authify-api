module Authify
  module API
    module Models
      class TrustedDelegate < ActiveRecord::Base
        include Core::SecureHashing

        attr_reader   :secret_key

        validates_uniqueness_of :name
        validates_uniqueness_of :access_key

        def secret_key=(unencrypted_string)
          @secret_key = unencrypted_string
          if unencrypted_string && !unencrypted_string.empty?
            self.secret_key_digest = salted_sha512(unencrypted_string)
          end
        end

        def compare_secret(unencrypted_string)
          compare_salted_sha512(unencrypted_string, secret_key_digest)
        end

        def set_secret!
          self.secret_key = self.class.generate_access_key + self.class.generate_access_key
        end

        def self.generate_access_key
          to_hex(SecureRandom.gen_random(32))[0...32]
        end

        def self.from_access_key(access, secret)
          trusted_delegate = find_by_access_key(access)
          if trusted_delegate && trusted_delegate.compare_secret(secret)
            trusted_delegate
          else
            nil
          end
        end
      end
    end
  end
end