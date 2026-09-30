Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

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
end
