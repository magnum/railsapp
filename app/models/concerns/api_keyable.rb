module ApiKeyable
  extend ActiveSupport::Concern

  included do
    has_many :api_keys, as: :bearer
  end

  def api_key!
    token = ApiKey.create!(bearer: self, account: account)
    token.raw_token
  end
end
