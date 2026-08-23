# Below are the routes for madmin
namespace :madmin, path: Settings.admin_prefix do
  resources :artists
  resources :people
  resources :rsvps
  resources :shows
  resources :venues
  resources :venue_groups
  root to: "dashboard#show"
end
