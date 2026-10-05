require "test_helper"

class OpenTest < ActiveSupport::TestCase
  test "the invite, confirm and remind scopes match their email type" do
    opens = %w[invite confirm remind].index_with { |type| Open.create!(tag: "some-show:#{type}", email: "#{type}@example.com") }

    %w[invite confirm remind].each do |type|
      assert_includes Open.public_send(type), opens[type]
      assert_equal [ opens[type] ], Open.public_send(type).where(id: opens.values.map(&:id)).to_a, type
    end
  end

  test "invites_to matches every invite type for the show, and only that show" do
    invite = Open.create!(tag: "some-show:invite", email: "a@example.com")
    unopened = Open.create!(tag: "some-show:invite_unopened", email: "b@example.com")
    Open.create!(tag: "some-show:confirm", email: "c@example.com")
    Open.create!(tag: "some-show-2:invite", email: "d@example.com")
    Open.create!(tag: "some_show:invite", email: "e@example.com")

    assert_equal [ invite, unopened ], Open.invites_to(Show.new(slug: "some-show")).order(:id).to_a
  end
end
