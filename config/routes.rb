Rails.application.routes.draw do
  get "/healthcheck", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
  )

  get "/healthcheck/live", to: proc { [200, {}, %w[OK]] }
  get "/healthcheck/ready", to: GovukHealthcheck.rack_response(
    GovukHealthcheck::ActiveRecord,
  )

  scope :api do
    scope :oauth2 do
      get "/sign-in", to: "authentication#sign_in"
      post "/callback", to: "authentication#callback"
      post "/state", to: "authentication#create_state"
    end

    get "/attributes", to: "attributes#show"
    patch "/attributes", to: "attributes#update"

    get "/transition-checker-email-subscription", to: "transition_checker_email_subscription#show"
    post "/transition-checker-email-subscription", to: "transition_checker_email_subscription#update"
  end
end
