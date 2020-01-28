# frozen_string_literal: true

module ComposeHook
  class Error < StandardError
  end

  class Payload
    def initialize(params)
      @secret = params[:secret]
      @expire = params[:expire] || 600

      raise ComposeHook::Error.new if @secret.to_s.empty?
      raise ComposeHook::Error.new unless @expire.positive?
    end

    def generate!(params)
      raise ComposeHook::Error.new if params[:service].to_s.empty?
      raise ComposeHook::Error.new if params[:image].to_s.empty?

      iat = params[:iat] || Time.now.to_i
      token = params.merge(
        'iat': iat,
        'exp': iat + @expire
      )

      JWT.encode(token, @secret, "HS256")
    end

    def decode!(token)
      JWT.decode(token, @secret, true, algorithm: "HS256").first
    end

    def safe_decode(token)
      decode!(token)
    rescue JWT::ExpiredSignature, JWT::ImmatureSignature, JWT::VerificationError, JWT::DecodeError
      nil
    end
  end
end
