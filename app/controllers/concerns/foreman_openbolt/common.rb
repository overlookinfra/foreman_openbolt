# frozen_string_literal: true

require 'foreman/logging'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  module Common
    extend ActiveSupport::Concern

    ENCRYPTED_PLACEHOLDER = '[Use saved encrypted default]'
    REDACTED_PLACEHOLDER = '*****'

    class LaunchError < StandardError; end

    # Raised by merge_encrypted_defaults when the caller submits the encrypted
    # placeholder for an option that has no saved Foreman setting.
    class MissingEncryptedDefault < StandardError; end

    # Raised by dispatch_task when the proxy has accepted the task but Foreman
    # cannot record or track it. The task is live, only the tracking failed.
    class PartialLaunchError < StandardError; end

    def openbolt_settings
      @openbolt_settings ||= Foreman.settings.select { |setting| setting.name.start_with?('openbolt_') }
    end

    def merge_encrypted_defaults(options)
      merged = options.dup
      merged.each do |key, value|
        next unless value == ENCRYPTED_PLACEHOLDER

        saved = Setting["openbolt_#{key}"]
        if saved.nil? || saved.to_s.empty?
          raise MissingEncryptedDefault,
            "No saved value for encrypted option '#{key}'. Configure it on the Foreman Settings page or provide a value."
        end
        merged[key] = saved
      end
      merged
    end

    def scrub_options_for_storage(options)
      scrubbed = options.dup
      openbolt_settings.select(&:encrypted?).each do |setting|
        option_name = setting.name.sub(/^openbolt_/, '')
        scrubbed[option_name] = REDACTED_PLACEHOLDER if scrubbed.key?(option_name)
      end
      scrubbed
    end

    def openbolt_options_with_defaults
      options = @openbolt_api.openbolt_options

      defaults = {}
      openbolt_settings.each do |setting|
        key = setting.name.sub(/^openbolt_/, '')
        if setting.encrypted?
          defaults[key] = ENCRYPTED_PLACEHOLDER unless setting.value.to_s.empty?
        elsif !setting.value.to_s.empty?
          defaults[key] = setting.value
        end
      end

      result = {}
      options.each do |name, meta|
        result[name] = meta.dup
        result[name]['default'] = defaults[name] if defaults.key?(name)
      end
      result
    end

    # before_action helpers shared by UI and API controllers
    def load_smart_proxy
      smart_proxy_id = params[:smart_proxy_id]
      if smart_proxy_id.blank?
        render_json_error('Smart Proxy ID is required', :bad_request)
        return
      end
      @smart_proxy = SmartProxy.authorized(:view_smart_proxies).find_by(id: smart_proxy_id)
      return if @smart_proxy
      render_json_error("Smart Proxy with ID #{smart_proxy_id} not found or not authorized", :not_found)
    end

    def load_openbolt_api
      return unless @smart_proxy
      @openbolt_api = ProxyAPI::Openbolt.new(url: @smart_proxy.url)
    rescue StandardError => e
      Foreman::Logging.exception("load_openbolt_api for proxy #{@smart_proxy.name}", e)
      render_json_error('Failed to connect to Smart Proxy', :bad_gateway)
    end

    # This shape matches Foreman's custom_error template, so UI
    # and API responses share one form regardless of which controller
    # produced them.
    def render_json_error(message, status)
      render json: { error: { message: message } }, status: status
    end
  end
end
