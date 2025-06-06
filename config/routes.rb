# For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  devise_for :admins
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root "shows#index"
  get "about" => "shows#about", as: "about"
  get "musicians" => "shows#musicians", as: "musicians"
  get "shows" => "shows#shows", as: "past_shows"
  get "privacy" => "privacy#index", as: "privacy"
  get "list" => "mailing_list#index", as: "mailing_list"
  get "unsubscribe/:uniqid" => "mailing_list#unsubscribe"
  get "calendar/ical" => "shows#ical"

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  resources :rsvps, only: %i[new index create]
  get "rsvps" => "rsvps#new", as: "rsvp"
  patch "rsvps" => "rsvps#create"
  get "rsvps/show/:slug" => "rsvps#new"
  get "rsvps/show/:slug/:uniqid" => "rsvps#new", as: "modify_rsvp"
  get "rsvps/show/:slug/:uniqid/:response" => "rsvps#new"
  post "rsvps/show/:slug" => "rsvps#new"

  post "sms" => "text_messages#receive"

  get "open/:tag/:uniqid" => "opens#index"

  resources :people, only: %i[new index create], controller: :mailing_list
end

Rails.application.routes.default_url_options = Rails.application.config.action_mailer.default_url_options
