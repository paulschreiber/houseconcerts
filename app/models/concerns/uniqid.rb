# A random public identifier, so records can be linked to without exposing
# their sequential ids.
module Uniqid
  extend ActiveSupport::Concern

  LENGTH = 16

  included do
    attribute :uniqid, default: -> { SecureRandom.alphanumeric(LENGTH) }
  end
end
