# frozen_string_literal: true

class ComposeHook::WebHook < Sinatra::Base
  class RequestError < StandardError; end
  class ServerError < StandardError; end

  set :show_exceptions, false

  def initialize(app=nil)
    super

    raise "WEBHOOK_JWT_SECRET is not set" if secret.to_s.empty?
    raise "CONFIG_PATH is not set" if ENV["CONFIG_PATH"].to_s.empty?
    raise "File #{ENV['CONFIG_PATH']} not found" unless File.exist?(ENV["CONFIG_PATH"])
  end

  def secret
    ENV["WEBHOOK_JWT_SECRET"]
  end

  def decoder
    ComposeHook::Payload.new(secret: secret)
  end

  def config
    config = YAML.load_file(ENV["CONFIG_PATH"])
    raise "The config file is empty or non-existent" if config.empty?

    config
  end

  def update_service(path, service, image)
    file = YAML.load_file(path)

    file["services"][service]["image"] = image
    File.write(path, file.to_yaml)
  end

  def find_service(service, path)
    puts "find_service: #{path}"

    Dir[File.join(path, "*.{yml,yaml}")].each do |file|
      begin
        return file unless YAML.load_file(file)["services"][service].empty?
      rescue StandardError => e
        warn "Error while parsing deployment files:", e
      end
    end
    raise RequestError.new("service #{service} not found")
  end

  before do
    content_type "application/json"
  end

  get "/deploy/ping" do
    "pong"
  end

  get "/deploy/:token" do |token|
    begin
      decoded = decoder.safe_decode(token)
      return answer(400, "invalid token") unless decoded

      service = decoded["service"]
      image = decoded["image"]
      hostname = request.host
      return answer(500, "configuration must be an array of hash") unless config.is_a?(Array)

      deployment = config.find {|d| d["domain"] == hostname }
      return answer(400, "unknown domain #{hostname}") unless deployment
      return answer(400, "root missing for #{hostname}") unless deployment["root"]

      service_file = find_service(service, File.join(deployment["root"], deployment["subpath"].to_s))
      return answer(400, "service is not specified") unless service
      return answer(400, "image is not specified") unless image
      return answer(404, "invalid domain") unless deployment
      return answer(404, "invalid service") unless service_file
      return answer(400, "invalid image format") if (%r(^(([-_\w\.]){,20}(\/|:))+([-\w\.]{,20})$) =~ image).nil?

      Kernel.system "docker image pull #{image}"

      unless $CHILD_STATUS.success?
        Kernel.system("docker image inspect #{image} > /dev/null")
        return answer(404, "invalid image") unless $CHILD_STATUS.success?
      end

      Dir.chdir(deployment["root"]) do
        update_service(service_file, service, image)
        Kernel.system "docker-compose up -Vd #{service}"
        raise ServerError.new("could not recreate the container") unless $CHILD_STATUS.success?
      end

      return answer(200, "service #{service} updated with image #{image}")
    rescue RequestError => e
      return answer(400, e.to_s)
    rescue ServerError => e
      return answer(500, e.to_s)
    rescue StandardError => e
      warn "Error: #{e}:\n#{e.backtrace.join("\n")}"
      return answer(500, "Internal server error")
    end
  end

  def answer(response_status, message)
    status response_status

    {
      message: message
    }.to_json
  end
end
