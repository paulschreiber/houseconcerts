# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  devise_for :admins
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root "shows#index"
  get "about", to: "shows#about", as: "about"
  get "musicians", to: "shows#musicians", as: "musicians"
  get "shows", to: "shows#shows", as: "past_shows"
  get "privacy", to: "privacy#index", as: "privacy"
  get "list", to: "mailing_list#index", as: "mailing_list"
  get "list/thanks/:uniqid", to: "mailing_list#thanks", as: "mailing_list_thanks"
  get "list/already_subscribed/:uniqid", to: "mailing_list#already_subscribed", as: "mailing_list_already_subscribed"
  get "unsubscribe/:uniqid", to: "mailing_list#unsubscribe", as: "unsubscribe"
  get "calendar/ical", to: "shows#ical"

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  resources :rsvps, only: %i[new index create]
  get "rsvps/thanks/:uniqid", to: "rsvps#thanks", as: "rsvp_thanks"
  get "rsvps", to: "rsvps#new", as: "rsvp"
  patch "rsvps", to: "rsvps#create"
  get "rsvps/show/:slug", to: "rsvps#new", as: "rsvp_for_show"
  get "rsvps/show/:slug/:uniqid", to: "rsvps#new", as: "modify_rsvp"
  get "rsvps/show/:slug/:uniqid/:response", to: "rsvps#new", as: "rsvp_response"
  post "rsvps/show/:slug", to: "rsvps#new"

  post "sms", to: "text_messages#receive"

  get "open/:tag/:uniqid", to: "opens#index", as: "open_tracking"

  resources :people, only: %i[new index create], controller: :mailing_list
end

Rails.application.routes.default_url_options = Rails.application.config.action_mailer.default_url_options
