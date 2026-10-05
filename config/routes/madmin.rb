# Below are the routes for madmin
namespace :madmin, path: Settings.admin_prefix do
  resources :artists
  resources :opens
  resources :people do
    member do
      patch :invite
      patch :rsvp_no
    end
    collection do
      get :import
      post :import, action: :run_import
    end
  end
  resources :rsvps do
    member do
      patch :confirm
      patch :waitlist
      patch :cancel
    end
  end
  resources :shows do
    member do
      get :attendance
      patch :attendance, action: :update_attendance
      get "attendance/print", action: :print_attendance, as: :print_attendance
      post :add_nonsubscribers
      post :add_phone_numbers
    end
  end
  resources :venues
  resources :venue_groups
  root to: "dashboard#show"
end
