Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "report", to: "report#show"

  namespace :api do
    namespace :v1 do
      resources :doses, only: [ :index, :create ]
      resource :settings, only: [ :show, :update ]
      resources :entries, only: [ :create ]
      get "glucose", to: "glucose#index"
      resources :activities, only: [ :index, :create ]
      resources :nutrition, only: [ :index, :create ]
      get "days", to: "days#index"
    end
  end

  # Unknown paths still answer with the documented error envelope.
  match "/", to: "errors#not_found", via: :all
  match "*path", to: "errors#not_found", via: :all
end
