require "test_helper"

class NamedSlugTest < ActiveSupport::TestCase
  [ Artist, Show, Venue ].each do |model|
    test "#{model}: a blank name gets no slug" do
      record = model.new(name: "")
      record.valid?

      assert_nil record.slug
    end

    test "#{model}: a rename changes the slug" do
      record = model.first
      record.name = "Jane Smith Live"
      record.valid?

      assert_equal "jane-smith-live", record.slug
    end
  end
end
