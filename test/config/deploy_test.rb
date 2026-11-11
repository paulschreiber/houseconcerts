require "test_helper"

class DeployConfigTest < ActiveSupport::TestCase
  # The `local` storage service holds the uploaded photos. A release's own
  # directory is replaced on every deploy, so Capistrano links it to shared/.
  test "the local storage directory is linked into each release" do
    root = Pathname(ActiveStorage::Blob.services.fetch(:local).root).relative_path_from(Rails.root).to_s
    line = Rails.root.join("config/deploy.rb").read[/^set :linked_dirs.*$/]

    assert line, "config/deploy.rb has no single-line `set :linked_dirs`"
    assert_includes line.scan(/"([^"]+)"/).flatten, root
  end
end
