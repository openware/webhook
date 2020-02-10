# frozen_string_literal: true

class ComposeHook::WebHook < Sinatra::Base
  class RequestError < StandardError; end
  class ServerError < StandardError; end

  attr_accessor :config, :secret, :decoder

  CONFIG_PATH = "compose/docker-compose.yml"
  STAGES_PATH = "/home/deploy/webhook/stages.yml"

  set :show_exceptions, false

  def initialize
    super

    @secret = ENV["WEBHOOK_JWT_SECRET"]
    raise "WEBHOOK_JWT_SECRET is not set" if @secret.to_s.empty?

    @config = YAML.load_file(ENV["CONFIG_PATH"])
    raise "The config file is empty or non-existent" if @config.empty?

    @decoder = ComposeHook::Payload.new(secret: secret)
  end

  def update_service(path, service, image)
    file = YAML.load_file(path)

    file["services"][service]["image"] = image
    File.write(path, file.to_yaml)
  end

  def find_service(service, path)
    res = ""

    Dir[File.join(path, "*.yml")].each do |file|
      begin
        res = file.path unless YAML.load_file(file)["services"][service].empty?
      rescue StandardError => e
        puts "Error while parsing deployment files:", e
      end
    end

    res
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

      service = decoded["service"]
      image = decoded["image"]
      hostname = request.host
      deployment = config.find { |d| d["domain"] == hostname }
      service_file = find_service(service, File.join(deployment["path"], deployment["subpath"]))

      return answer(400, "service is not specified") unless service
      return answer(400, "image is not specified") unless image
      return answer(404, "invalid domain") unless deployment
      return answer(404, "invalid service") unless service_file
      return answer(400, "invalid image") if (%r(^(([-_\w\.]){,20}(\/|:))+([-\w\.]{,20})$) =~ image).nil?

      system "docker image pull #{image}"

      unless $CHILD_STATUS.success?
        system("docker image inspect #{image} > /dev/null")
        return answer(404, "invalid image") unless $CHILD_STATUS.success?
      end

      Dir.chdir(deployment["root"]) do
        update_service(service_file, service, image)
        system "docker-compose up -Vd #{service}"
        raise ServerError.new("could not recreate the container") unless $CHILD_STATUS.success?
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
