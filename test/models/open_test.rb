require "test_helper"

class OpenTest < ActiveSupport::TestCase
  test "the invite, confirm and remind scopes match their email type" do
    opens = %w[invite confirm remind].index_with { |type| Open.create!(tag: "some-show:#{type}", email: "#{type}@example.com") }

    %w[invite confirm remind].each do |type|
      assert_includes Open.public_send(type), opens[type]
      assert_equal [ opens[type] ], Open.public_send(type).where(id: opens.values.map(&:id)).to_a, type
    end
  end
end
