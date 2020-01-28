# frozen_string_literal: true

require "json"
require "yaml"
require "sinatra/base"
require "jwt"

require_relative "compose_hook/payload"
require_relative "compose_hook/webhook"
