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
  resources :shows do
    member do
      patch :send_invites
      patch :send_invites_unopened
      patch :send_reminders
      patch :retry_failed_batch_run
    end
  end
  resources :venues
  resources :venue_groups
  root to: "dashboard#show"
end
