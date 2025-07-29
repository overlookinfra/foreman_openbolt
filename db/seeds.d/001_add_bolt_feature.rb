# frozen_string_literal: true

f = Feature.where(name: 'Bolt').first_or_create
raise "Unable to create bolt proxy feature: #{format_errors f}" if f.nil? || f.errors.any?

SmartProxy.find_each(&:refresh)
