# frozen_string_literal: true

require 'rake/testtask'

# Tasks
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

# Tests
namespace :test do
  desc 'Test ForemanOpenbolt'
  Rake::TestTask.new(:foreman_openbolt) do |t|
    test_dir = File.expand_path('../../test', __dir__)
    t.libs << 'test'
    t.libs << test_dir
    t.pattern = "#{test_dir}/**/*_test.rb"
    t.verbose = true
    t.warning = false
  end
end

Rake::Task[:test].enhance ['test:foreman_openbolt']

load 'tasks/jenkins.rake'
Rake::Task['jenkins:unit'].enhance ['test:foreman_openbolt', 'foreman_openbolt:rubocop'] if Rake::Task.task_defined?(:'jenkins:unit')
