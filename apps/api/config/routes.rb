Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The application API lives under /api/v1 (D-031).
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      get "csrf_token", to: "csrf_tokens#show"
    end
  end

  # Any other path or method under /api is a JSON 404 (D-078). Keep this below
  # every /api route: the first match wins.
  match "api(/*unmatched)", to: "api/errors#not_found", via: :all, format: false

  # Defines the root path route ("/")
  # root "posts#index"
end
