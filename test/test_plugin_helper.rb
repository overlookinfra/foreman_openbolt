# frozen_string_literal: true

require 'test_helper'
require 'dynflow/testing'

# Load plugin factories and foreman-tasks factories
FactoryBot.definition_file_paths << File.join(File.dirname(__FILE__), 'factories')
FactoryBot.definition_file_paths << File.join(ForemanTasks::Engine.root, 'test', 'factories')
FactoryBot.reload

module ForemanOpenbolt
  class PluginTestCase < ActiveSupport::TestCase
    teardown do
      WebMock.reset!
    end
  end
end
