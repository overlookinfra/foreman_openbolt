# frozen_string_literal: true

FactoryBot.define do
  factory :task_job, class: 'ForemanOpenbolt::TaskJob' do
    sequence(:job_id) { |n| "test-job-#{n}" }
    association :smart_proxy
    task_name { 'mymod::install' }
    task_description { 'Install a package on the target host' }
    status { 'pending' }
    targets { ['host1.example.com', 'host2.example.com'] }
    task_parameters { { 'name' => 'nginx' } }
    openbolt_options { { 'transport' => 'ssh' } }

    trait :running do
      status { 'running' }
    end

    trait :success do
      status { 'success' }
      completed_at { Time.current }
      result { { 'items' => [{ 'target' => 'host1.example.com', 'status' => 'success' }] } }
      log { 'Started: task mymod::install\nFinished: success' }
      command { 'bolt task run mymod::install --targets host1.example.com' }
    end

    trait :failure do
      status { 'failure' }
      completed_at { Time.current }
      result { { 'items' => [{ 'target' => 'host1.example.com', 'status' => 'failure' }] } }
      log { 'Started: task mymod::install\nFinished: failure' }
    end

    trait :exception do
      status { 'exception' }
      completed_at { Time.current }
    end
  end
end
