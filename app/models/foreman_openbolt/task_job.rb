# frozen_string_literal: true

module ForemanOpenbolt
  class TaskJob < ApplicationRecord
    self.table_name = 'openbolt_task_jobs'
    self.primary_key = 'job_id'

    # Constants
    STATUSES = %w[pending running success failure exception invalid].freeze
    COMPLETED_STATUSES = %w[success failure exception invalid].freeze
    RUNNING_STATUSES = %w[pending running].freeze

    # Associations
    belongs_to :smart_proxy

    # Validations
    validates :task_name, presence: true
    validates :job_id, presence: true, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validates :targets, presence: true
    validates :submitted_at, presence: true

    # Scopes
    scope :running, -> { where(status: RUNNING_STATUSES) }
    scope :completed, -> { where(status: COMPLETED_STATUSES) }
    scope :recent, -> { order(submitted_at: :desc) }
    scope :for_proxy, ->(proxy) { where(smart_proxy: proxy) }

    # Callbacks
    before_validation :set_submitted_at, on: :create
    before_update :set_completed_at, if: :status_changed_to_completed?
    after_update :cleanup_proxy_artifacts, if: :saved_result_and_log?

    # Class methods
    def self.create_from_execution!(proxy:, task_name:, targets:, job_id:, parameters: {}, options: {})
      create!(
        job_id: job_id,
        smart_proxy: proxy,
        task_name: task_name,
        targets: targets,
        task_parameters: parameters,
        openbolt_options: options,
        status: 'pending'
        # submitted_at is set by callback
      )
    end

    def completed?
      status.in?(COMPLETED_STATUSES)
    end

    def running?
      status.in?(RUNNING_STATUSES)
    end

    def duration
      return nil unless submitted_at && completed_at
      completed_at - submitted_at
    end

    # Result/log will already be scrubbed by the proxy
    def update_from_proxy_result!(proxy_result)
      return if proxy_result.blank?

      transaction do
        self.status = proxy_result['status'] if proxy_result['status'].present?
        self.command = proxy_result['command'] if proxy_result['command'].present?
        self.result = proxy_result['value'] if proxy_result.key?('value')
        self.log = proxy_result['log'] if proxy_result.key?('log')
        save!
      end
    end

    def target_count
      targets&.size || 0
    end

    def formatted_targets
      targets&.join(', ') || ''
    end

    private

    def set_submitted_at
      self.submitted_at ||= Time.current
    end

    def set_completed_at
      self.completed_at ||= Time.current if completed?
    end

    def status_changed_to_completed?
      status_changed? && completed?
    end

    def saved_result_and_log?
      saved_change_to_result? || saved_change_to_log?
    end

    def cleanup_proxy_artifacts
      return unless result.present? && log.present?
      # Schedule cleanup of proxy artifacts if we have successfully saved the results
      # ForemanTasks.async_task(::Actions::ForemanOpenbolt::CleanupProxyArtifacts,
      #   smart_proxy_id,
      #   job_id)
      # Rails.logger.info("Scheduled cleanup for job #{job_id} on proxy #{smart_proxy_id}")
    end
  end
end
