require "test_helper"
require "open3"

class EagerLoadedBootTest < ActiveSupport::TestCase
  # Production eager loads, which loads the routes before Active Storage reads
  # its draw_routes setting. The tests boot without eager loading, so they'd
  # not see Active Storage's routes clash with config/routes.rb.
  test "the app boots with eager loading, with only the photo sizes' route from Active Storage" do
    script = "puts Rails.application.routes.named_routes.names.grep(/\\Arails_(service|disk|direct|blob)/).inspect"
    output, status = Open3.capture2e({ "CI" => "1", "RAILS_ENV" => "test" }, Rails.root.join("bin/rails").to_s, "runner", script)

    assert_predicate status, :success?, output
    assert_equal "[:rails_blob_representation_proxy]", output.lines.last.strip
  end
end
