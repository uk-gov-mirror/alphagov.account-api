RSpec.describe OidcClient do
  subject(:client) { described_class.new }

  before { stub_oidc_discovery }

  describe "tokens!" do
    before do
      access_token = Rack::OAuth2::AccessToken.new(
        access_token: "access-token",
        refresh_token: "refresh-token",
        token_type: "test",
      )

      @client_stub = stub_oidc_client(client)
      # rubocop:disable RSpec/InstanceVariable
      allow(@client_stub).to receive(:access_token!).and_return(access_token)
      # rubocop:enable RSpec/InstanceVariable
    end

    it "doesn't fetch an ID token by default" do
      expect(client.tokens!).to eq({ access_token: "access-token", refresh_token: "refresh-token" })
    end

    it "fetches an ID token if a nonce is provided" do
      # the OAuth2::AccessToken type doesn't implement #id_token, so we get a NoMethodError
      expect { client.tokens!(oidc_nonce: "nonce") }.to raise_error(NoMethodError)
    end

    it "converts a Rack::OAuth2 error into an OAuthFailure" do
      # rubocop:disable RSpec/InstanceVariable
      allow(@client_stub).to receive(:access_token!).and_raise(Rack::OAuth2::Client::Error.new(401, { error: "error", error_description: "description" }))
      # rubocop:enable RSpec/InstanceVariable

      expect { client.tokens! }.to raise_error(OidcClient::OAuthFailure)
    end
  end

  describe "get_ephemeral_state" do
    it "returns {} if there is no JSON" do
      stub_request(:get, Plek.find("account-manager") + "/api/v1/ephemeral-state").to_return(body: "")

      expect(client.get_ephemeral_state(access_token: "access-token", refresh_token: "refresh-token")).to eq({ access_token: "access-token", refresh_token: "refresh-token", result: {} })
    end
  end

  describe "submit_jwt" do
    it "raises an error if there is no JSON" do
      stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt").to_return(body: "")

      expect { client.submit_jwt(jwt: "foo", access_token: "access-token", refresh_token: "refresh-token") }.to raise_error(OidcClient::OAuthFailure)
    end
  end

  describe "the access token has expired" do
    before do
      stub = stub_oidc_client(client)
      allow_token_refresh(stub)

      @stub_fail = stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt")
        .with(headers: { Authorization: "Bearer access-token" })
        .to_return(status: 401)
    end

    it "refreshes the token and retries" do
      stub_success = stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt")
        .with(headers: { Authorization: "Bearer new-access-token" })
        .to_return(status: 200, body: { id: "foo" }.to_json)

      client.submit_jwt(jwt: "", access_token: "access-token", refresh_token: "refresh-token")

      # rubocop:disable RSpec/InstanceVariable
      expect(@stub_fail).to have_been_made
      # rubocop:enable RSpec/InstanceVariable
      expect(stub_success).to have_been_made
    end

    context "but there is no refresh token" do
      it "fails" do
        expect { client.submit_jwt(jwt: "", access_token: "access-token", refresh_token: nil) }.to raise_error(OidcClient::OAuthFailure)
      end
    end

    context "but the refreshed access token fails" do
      it "fails" do
        stub_request(:post, Plek.find("account-manager") + "/api/v1/jwt")
          .with(headers: { Authorization: "Bearer new-access-token" })
          .to_return(status: 401)

        expect { client.submit_jwt(jwt: "", access_token: "access-token", refresh_token: "refresh-token") }.to raise_error(OidcClient::OAuthFailure)
      end
    end
  end
end
