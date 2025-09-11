# frozen_string_literal: true

f = Feature.where(name: 'OpenBolt').first_or_create
raise "Unable to create OpenBolt proxy feature: #{format_errors f}" if f.nil? || f.errors.any?

SmartProxy.find_each(&:refresh)
