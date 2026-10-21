require "test_helper"
require Rails.root.join("db/migrate/20261021200000_decode_html_entities_in_rsvps")

class DecodeHtmlEntitiesInRsvpsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  def migrate
    ActiveRecord::Migration.suppress_messages { DecodeHtmlEntitiesInRsvps.new.up }
  end

  test "decodes the entities ModelCleaners stored in last names and referrers, without callbacks" do
    rsvp = rsvps(:one)
    rsvp.update_columns(last_name: "Smith &amp; Li&nbsp;&lt;3", referrer: "https://example.com/?a=1&amp;b=2") # rubocop:disable Rails/SkipsModelValidations
    updated_at = rsvp.reload.updated_at

    assert_no_emails { migrate }

    assert_equal "Smith & Li\u00a0<3", rsvp.reload.last_name
    assert_equal "https://example.com/?a=1&b=2", rsvp.referrer
    assert_equal updated_at, rsvp.updated_at
  end

  test "decodes each entity once" do
    rsvp = rsvps(:one)
    rsvp.update_columns(last_name: "Use &amp;lt;b&amp;gt;") # rubocop:disable Rails/SkipsModelValidations

    migrate

    assert_equal "Use &lt;b&gt;", rsvp.reload.last_name
  end

  test "leaves text without those entities alone" do
    rsvp = rsvps(:one)
    rsvp.update_columns(last_name: "Smith & Li < Jones &copy;") # rubocop:disable Rails/SkipsModelValidations

    migrate

    assert_equal "Smith & Li < Jones &copy;", rsvp.reload.last_name
  end
end
