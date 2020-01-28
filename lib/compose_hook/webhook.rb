# frozen_string_literal: true

class ComposeHook::WebHook < Sinatra::Base
  class RequestError < StandardError; end
  class ServerError < StandardError; end

  CONFIG_PATH = "compose/docker-compose.yml"
  STAGES_PATH = "/home/deploy/webhook/stages.yml"

  set :show_exceptions, false

  def initialize
    super
    secret = ENV["WEBHOOK_JWT_SECRET"]
    raise "WEBHOOK_JWT_SECRET is not set" if secret.to_s.empty?

    @decoder = ComposeHook::Payload.new(secret: secret)
  end

  def update_config(service, image)
    config = YAML.load_file(CONFIG_PATH)
    raise RequestError.new("Unknown service") if config["services"][service].nil?

    config["services"][service]["image"] = image
    File.open(CONFIG_PATH, "w") {|f| f.write config.to_yaml }
  end

  before do
    content_type "application/json"
  end

  get "/deploy/ping" do
    "pong"
  end

  get "/deploy/:token" do |token|
    begin
      decoded = @decoder.safe_decode(token)
      return answer(400, "invalid token") unless decoded

      stages = YAML.load_file(STAGES_PATH)

      service = decoded["service"]
      image = decoded["image"]
      hostname = request.host
      stage_path = stages.find {|s| s["domain"] == hostname }["path"]

      return answer(400, "service is not specified") unless service
      return answer(400, "image is not specified") unless image
      return answer(404, "invalid domain") unless stage_path
      return answer(400, "invalid image") if (%r(^(([-_\w\.]){,20}(\/|:))+([-\w\.]{,20})$) =~ image).nil?

      system "docker image pull #{image}"

      unless $CHILD_STATUS.success?
        system("docker image inspect #{image} > /dev/null")
        return answer(404, "invalid image") unless $CHILD_STATUS.success?
      end

      Dir.chdir(stage_path) do
        update_config(service, image)
        system "docker-compose up -Vd #{service}"
        raise ServerError.new("could not restart container") unless $CHILD_STATUS.success?
      end

      return answer(200, "service #{service} updated with image #{image}")
    rescue RequestError => e
      return answer(400, e.to_s)
    rescue ServerError => e
      return answer(500, e.to_s)
    end
  end

  def answer(response_status, message)
    status response_status

    {
      message: message
    }.to_json
  end
end
