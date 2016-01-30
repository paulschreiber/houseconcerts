Rails.application.routes.draw do
  devise_for :admins
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'shows#index'
  get 'about' => 'shows#about', as: 'about'
  get 'musicians' => 'shows#musicians', as: 'musicians'
  get 'shows' => 'shows#shows', as: 'past_shows'
  get 'list' => 'mailing_list#index', as: 'mailing_list'
  get 'unsubscribe/:uniqid' => 'mailing_list#unsubscribe'
  get 'calendar/ical' => 'shows#ical'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  resources :rsvps, only: [:new, :index, :create]
  get 'rsvps' => 'rsvps#new', as: 'rsvp'
  patch 'rsvps' => 'rsvps#create'
  get 'rsvps/show/:slug' => 'rsvps#new'
  get 'rsvps/show/:slug/:uniqid' => 'rsvps#new'
  get 'rsvps/show/:slug/:uniqid/:response' => 'rsvps#new'
  post 'rsvps/show/:slug' => 'rsvps#new'

  # Handle legacy URLs/typos
  get '/rsvp/show/:slug' => redirect('/rsvps')


  get 'open/:tag/:uniqid' => 'opens#index'

  resources :people, only: [:new, :index, :create], controller: :mailing_list

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
