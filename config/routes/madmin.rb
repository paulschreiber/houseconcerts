# Below are the routes for madmin
namespace :madmin, path: Settings.admin_prefix do
  resources :admins
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
      patch :start_batch_run
      patch :retry_failed_batch_run
      patch :cancel_batch_run
    end
    # The show's invite revisions. Previewing renders the editor's unsaved
    # text (posted, or patched from the edit form) or a saved revision.
    resources :invite_messages, path: "invite" do
      match :preview, on: :collection, via: %i[post patch]
      get :preview, on: :member
      post :send_test, on: :member
    end
  end
  # Every show's invite revisions (InviteResource). Each revision's own page
  # is the show's, above.
  resources :invite_messages, only: :index, path: "invites", controller: "invites"
  resources :venues
  resources :venue_groups
  root to: "dashboard#show"
end
