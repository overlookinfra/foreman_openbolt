# frozen_string_literal: true

namespace :openbolt do
  desc 'Refresh smart proxy features to detect OpenBolt feature'
  task refresh_proxies: :environment do
    puts "Refreshing smart proxies to detect OpenBolt feature"
    proxies = SmartProxy.unscoped
    proxies.each do |proxy|
      print "Refreshing #{proxy.name}... "
      begin
        proxy.refresh
        proxy.reload
        has_feature = proxy.features.map(&:name).include?('OpenBolt')
        puts has_feature ? 'OpenBolt FOUND' : 'OpenBolt NOT FOUND'
      rescue StandardError => e
        puts "FAILED: #{e.message}"
      end
    end

    if proxies.count.zero?
      puts "No smart proxies found"
    else
      openbolt_count = proxies.with_features('OpenBolt').count
      puts "Total proxies with OpenBolt: #{openbolt_count}/#{proxies.count}"
    end
  end
end
