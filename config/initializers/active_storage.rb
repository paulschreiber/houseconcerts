# Set here, not only through config.active_storage.draw_routes (see
# config/application.rb): Active Storage copies that setting in an
# after_initialize hook, but Devise loads the routes earlier when the app eager
# loads (production), and Active Storage's own routes would clash with ours.
# (Active Storage in Rails 8.1.4.1.)
ActiveStorage.draw_routes = false
