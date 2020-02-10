# frozen_string_literal: true

describe ComposeHook::WebHook do
  let(:config_path) { "config/deployments.yml" }
  let(:secret) { "47bca2f902a2d876117749544fed8620e246c29e" }
  let(:jwt) { "eyJhbGciOiJIUzI1NiJ9.eyJzZXJ2aWNlIjoic29tZV9zZXJ2aWNlIiwiaW1hZ2UiOiJ5b3VyX2ltYWdlIiwiaWF0IjoxNTgwMjA1NjMyLCJleHAiOjE4OTU1NjU2MzJ9.0csHOLQncT4qMmyRZ6Qg8SSAK6hOxMLydQUFfZO6fcM" }

  context "respond to ping" do
    it do
      allow(ENV).to receive(:[]).with("CONFIG_PATH").and_return(config_path)
      allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return(secret)
      get '/deploy/ping'
      expect(last_response).to be_ok
    end
  end

  context "invalid params" do
    context "invalid token" do
      it do
        get "deploy/invalid_token"
        expect(last_response.status).to eq(400)
      end
    end
  end

 # TODO: Implement stages.yml file fixture
 #  context "incomplete params" do
 #    it do
 #      allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return(secret)
 #      get "deploy/#{jwt}"
 #      expect(last_response.status).to eq(400)
 #    end
 #  end

 #  context "invalid domain" do
 #    it do
 #      allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return(secret)
 #      header "Host", "invalid.domain.com"
 #      get "deploy/#{jwt}"
 #      puts last_response
 #      expect(last_response.status).to eq(404)
 #    end
 #  end
end
