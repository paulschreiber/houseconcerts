# Below are the routes for madmin
namespace :madmin, path: Settings.admin_prefix do
  resources :artists
  resources :opens
  resources :people do
    member do
      patch :invite
    end
  end
  resources :rsvps do
    member do
      patch :confirm
      patch :waitlist
    end
  end
  resources :shows
  resources :venues
  resources :venue_groups
  root to: "dashboard#show"
end
