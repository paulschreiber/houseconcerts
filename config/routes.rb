# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  draw :madmin
  devise_for :admins, skip: [ :registrations ], path: Settings.admin_prefix
  mount MissionControl::Jobs::Engine, at: "#{Settings.admin_prefix}/jobs"
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root "shows#index"
  get "about", to: "shows#about", as: "about"
  get "musicians", to: "shows#musicians", as: "musicians"
  get "shows", to: "shows#shows", as: "past_shows"
  get "privacy", to: "privacy#index", as: "privacy"
  # The RSVP and mailing-list pages are HTML only (see HtmlOnly), so their
  # routes don't take a format suffix: /rsvps.json is a 404.
  scope format: false do
    get "list", to: "mailing_list#index", as: "mailing_list"
    get "list/thanks/:uniqid", to: "mailing_list#thanks", as: "mailing_list_thanks"
    get "list/already_subscribed", to: "mailing_list#already_subscribed", as: "mailing_list_already_subscribed"
    get "list/rejoin_requested", to: "mailing_list#rejoin_requested", as: "mailing_list_rejoin_requested"
    get "list/rejoin/:uniqid", to: "mailing_list#rejoin", as: "mailing_list_rejoin"
    post "list/rejoin/:uniqid", to: "mailing_list#confirm_rejoin"
    get "unsubscribe/:uniqid", to: "mailing_list#unsubscribe", as: "unsubscribe"
    post "unsubscribe/:uniqid", to: "mailing_list#one_click_unsubscribe"
  end
  get "calendar/", to: "shows#calendar", as: "calendar"

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  scope format: false do
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

  get "open/:tag/:uniqid", to: "opens#index", as: "open_tracking"

  resources :people, only: %i[new index create], controller: :mailing_list, format: false
end

Rails.application.routes.default_url_options = Rails.application.config.action_mailer.default_url_options
