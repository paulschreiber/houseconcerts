# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  draw :madmin
  devise_for :admins, skip: [ :registrations ], path: Settings.admin_prefix, controllers: { passkeys: "admins/passkeys" }
  # devise-webauthn has no index route; this is the passkeys page.
  devise_scope :admin do
    get "#{Settings.admin_prefix}/passkeys", to: "admins/passkeys#index", as: nil
  end
  mount MissionControl::Jobs::Engine, at: "#{Settings.admin_prefix}/jobs"

  root "shows#index"
  get "about", to: "shows#about", as: "about"
  get "musicians", to: "shows#musicians", as: "musicians"
  get "shows", to: "shows#shows", as: "past_shows"
  get "privacy", to: "privacy#index", as: "privacy"
  # The RSVP and mailing-list pages take form submissions, so their controllers
  # refuse anything but HTML up front (see HtmlOnly) and their routes don't take
  # a format suffix: /rsvps.json is a 404. The other pages only have HTML
  # templates, so Rails answers other formats with a 406.
  scope format: false do
    get "list", to: "mailing_list#index", as: "mailing_list"
    get "list/thanks/:uniqid", to: "mailing_list#thanks", as: "mailing_list_thanks"
    get "list/already_subscribed", to: "mailing_list#already_subscribed", as: "mailing_list_already_subscribed"
    get "list/rejoin_requested", to: "mailing_list#rejoin_requested", as: "mailing_list_rejoin_requested"
    get "list/rejoin/:uniqid", to: "mailing_list#rejoin", as: "mailing_list_rejoin"
    post "list/rejoin/:uniqid", to: "mailing_list#confirm_rejoin"
    get "unsubscribe/:uniqid", to: "mailing_list#unsubscribe", as: "unsubscribe"
    post "unsubscribe/:uniqid", to: "mailing_list#one_click_unsubscribe"
    # The sign-up form posts here; a failed sign-up re-renders at /people.
    resources :people, only: %i[index create], controller: :mailing_list

    resources :rsvps, only: %i[new index create]
    get "rsvps/thanks/:uniqid", to: "rsvps#thanks", as: "rsvp_thanks"
    get "rsvps/updated", to: "rsvps#updated", as: "rsvp_updated"
    patch "rsvps", to: "rsvps#create"
    get "rsvps/show/:slug", to: "rsvps#new", as: "rsvp_for_show"
    get "rsvps/show/:slug/:uniqid", to: "rsvps#new", as: "modify_rsvp"
    get "rsvps/show/:slug/:uniqid/:response", to: "rsvps#new", as: "rsvp_response"
  end

  post "sms", to: "text_messages#receive"
  post "ses", to: "ses_events#create", as: "ses_events", format: false

  # The iCalendar feed, at /calendar or /calendar.ics.
  get "calendar", to: "shows#calendar", as: "calendar", constraints: { format: "ics" }
  get "open/:tag/:uniqid", to: "opens#index", as: "open_tracking"
end

Rails.application.routes.default_url_options = Rails.application.config.action_mailer.default_url_options
