module Authify
  module API
    module Serializers
      # JSON API Serializer for Organization model
      class OrganizationSerializer
        include JSONAPI::Serializer

        attribute :name
        attribute :description
        has_many :groups
        has_many :users
      end
    end
  end
end
