class BatchRunItem < ApplicationRecord
  belongs_to :batch_run
  belongs_to :recipient, polymorphic: true

  enum :status, { pending: 0, sent: 1, failed: 2 }, default: :pending
end
