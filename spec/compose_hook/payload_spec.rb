# frozen_string_literal: true

describe ComposeHook::Payload do
  let(:payload) { ComposeHook::Payload.new(params) }
  let(:params) do
    {
      secret: secret,
      expire: expire,
    }
  end

  let(:secret) { "47bca2f902a2d876117749544fed8620e246c29e" }
  let(:expire) { 315_360_000 }

  context "generate an encrypted payload" do
    it do
      expect(payload.generate!(service: "some_service", image: "your_image", iat: 1_580_205_632)).to \
        eq("eyJhbGciOiJIUzI1NiJ9.eyJzZXJ2aWNlIjoic29tZV9zZXJ2aWNlIiwiaW1hZ2UiOiJ5b3VyX2ltYWdlIiwiaWF0IjoxNTgwMjA1NjMyLCJleHAiOjE4OTU1NjU2MzJ9.0csHOLQncT4qMmyRZ6Qg8SSAK6hOxMLydQUFfZO6fcM")
    end
  end

  context "decrypt a payload" do
    it do
      expect(payload.decode!("eyJhbGciOiJIUzI1NiJ9.eyJzZXJ2aWNlIjoic29tZV9zZXJ2aWNlIiwiaW1hZ2UiOiJ5b3VyX2ltYWdlIiwiaWF0IjoxNTgwMjA1NjMyLCJleHAiOjE4OTU1NjU2MzJ9.0csHOLQncT4qMmyRZ6Qg8SSAK6hOxMLydQUFfZO6fcM")).to \
        eq("service" => "some_service", "image" => "your_image", "iat" => 1_580_205_632, "exp" => 1_895_565_632)
    end
  end

  context "invalid arguments to initialize" do
    context "negative expire" do
      let(:expire) { -10 }
      it { expect { payload }.to raise_error(ComposeHook::Error) }
    end

    context "nil secret" do
      let(:secret) { nil }
      it { expect { payload }.to raise_error(ComposeHook::Error) }
    end

    context "empty secret" do
      let(:secret) { "" }
      it { expect { payload }.to raise_error(ComposeHook::Error) }
    end
  end

  context "invalid arguments to generate!" do
    context "service missing" do
      it { expect { payload.generate!(image: "myimage") }.to raise_error(ComposeHook::Error) }
    end
    context "service empty" do
      it { expect { payload.generate!(image: "myimage", service: "") }.to raise_error(ComposeHook::Error) }
    end
    context "image missing" do
      it { expect { payload.generate!(service: "your_service") }.to raise_error(ComposeHook::Error) }
    end
    context "image empty" do
      it { expect { payload.generate!(image: "", service: "your_service") }.to raise_error(ComposeHook::Error) }
    end
  end
end
