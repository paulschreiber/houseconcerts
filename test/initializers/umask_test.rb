require "test_helper"

class UmaskTest < ActiveSupport::TestCase
  setup do
    @original_umask = File.umask
    @original_env = Rails.env
    @original_tasks = Rake.application.top_level_tasks.dup
  end

  teardown do
    File.umask(@original_umask)
    Rails.env = @original_env
    Rake.application.top_level_tasks.replace(@original_tasks)
  end

  test "production closes new files to everyone outside the group" do
    run_initializer("production", [ "db:migrate" ])

    assert_equal 0o007, File.umask
  end

  test "precompiling assets in production leaves new files world-readable" do
    File.umask(0o022)

    run_initializer("production", [ "assets:precompile" ])

    assert_equal 0o022, File.umask
  end

  test "other environments keep the default umask" do
    File.umask(0o022)

    run_initializer("development", [])

    assert_equal 0o022, File.umask
  end

  private

    def run_initializer(env, tasks)
      Rails.env = env
      Rake.application.top_level_tasks.replace(tasks)
      load Rails.root.join("config/initializers/umask.rb")
    end
end
