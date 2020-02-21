# frozen_string_literal: true

require "fileutils"

describe ComposeHook::WebHook do
  let(:config_file) do
    file = Tempfile.new("config")
    file.write(YAML.dump(config))
    file.close
    file
  end
  let(:config) do
    [
      {
        "domain"  => "example.org",
        "root"    => File.join(File.dirname(__FILE__), "../../"),
        "subpath" => "config",
      }
    ]
  end
  let(:config_path) { config_file.path }
  let(:secret) { "47bca2f902a2d876117749544fed8620e246c29e" }
  let(:jwt) { "eyJhbGciOiJIUzI1NiJ9.eyJzZXJ2aWNlIjoic29tZV9zZXJ2aWNlIiwiaW1hZ2UiOiJ5b3VyX2ltYWdlIiwiaWF0IjoxNTgwMjA1NjMyLCJleHAiOjE4OTU1NjU2MzJ9.0csHOLQncT4qMmyRZ6Qg8SSAK6hOxMLydQUFfZO6fcM" }

  before(:each) do
    allow(ENV).to receive(:[]).and_return(nil)
  end

  def get_jwt(service, image, the_secret)
    ComposeHook::Payload.new(secret: the_secret).generate!(service: service, image: image)
  end

  context "invalid configuration" do
    context "missing WEBHOOK_JWT_SECRET" do
      it do
        allow(ENV).to receive(:[]).with("CONFIG_PATH").and_return(config_path)
        allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return("")

        expect { get "deploy/anything" }.to raise_error(StandardError)
      end
    end
    context "missing CONFIG_PATH" do
      it do
        allow(ENV).to receive(:[]).with("CONFIG_PATH").and_return("")
        allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return(secret)
        expect { get "deploy/anything" }.to raise_error(StandardError)
      end
    end
  end

  context "valid configuration" do
    before(:each) do
      allow(ENV).to receive(:[]).with("CONFIG_PATH").and_return(config_path)
      allow(ENV).to receive(:[]).with("WEBHOOK_JWT_SECRET").and_return(secret)
    end

    context "invalid domain" do
      let(:config) do
        [
          {
            "domain"  => "example.com",
            "root"    => "/home/deploy/example",
            "subpath" => "compose",
          }
        ]
      end
      it do
        get "deploy/%<token>s" % {token: get_jwt("web", "jwilder/dockerize:latest", secret)}
        expect(JSON.parse(last_response.body)).to eq("message"=>"unknown domain example.org")
        expect(last_response.status).to eq(400)
      end
    end

    context "invalid config file" do
      let(:config) do
        {
          "domain"  => "example.org",
          "root"    => "/home/deploy/example",
          "subpath" => "compose",
        }
      end
      it do
        get "deploy/%<token>s" % {token: get_jwt("web", "jwilder/dockerize:latest", secret)}
        expect(JSON.parse(last_response.body)).to eq("message"=>"configuration must be an array of hash")
        expect(last_response.status).to eq(500)
      end
    end

    it do
      get "/deploy/ping"
      expect(last_response).to be_ok
    end

    it do
      get "deploy/%<token>s" % {token: get_jwt("web", "jwilder/dockerize:latest", "wrong_secret")}
      expect(JSON.parse(last_response.body)).to eq("message"=>"invalid token")
      expect(last_response.status).to eq(400)
    end

    it do
      get "deploy/%<token>s" % {token: get_jwt("web", "jwilder/dockerize:latest", secret)}
      expect(JSON.parse(last_response.body)).to eq("message"=>"service web not found")
      expect(last_response.status).to eq(400)
    end

    it do
      expect(Kernel).to receive(:system).with("docker image pull quay.io/openware/barong:2.4.6").and_return(true)
      expect(Kernel).to receive(:system).with("docker-compose up -Vd barong").and_return(true)

      get "deploy/%<token>s" % {token: get_jwt("barong", "quay.io/openware/barong:2.4.6", secret)}
      expect(JSON.parse(last_response.body)).to eq("message"=>"service barong updated with image quay.io/openware/barong:2.4.6")
      expect(last_response.status).to eq(200)
      expect(YAML.load_file(File.join(File.dirname(__FILE__), "../../config/docker-compose.yml"))).to eq(
        "version"  => "3.6",
        "services" => {
          "barong" => {
            "restart" => "always",
            "image"   => "quay.io/openware/barong:2.4.6",
          }
        }
      )
    end
  end
end
