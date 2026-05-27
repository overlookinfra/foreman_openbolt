# frozen_string_literal: true

module ForemanOpenbolt
  module Jobs
    extend ActiveSupport::Concern
    include ForemanOpenbolt::Common

    included do
      before_action :load_task_job, only: [:job_status, :job_result]
    end

    def find_task_job(job_id)
      return nil if job_id.blank?
      task_job = ForemanOpenbolt::TaskJob.find_by(job_id: job_id)
      logger.debug { "find_task_job(#{job_id.inspect}) -> #{task_job.inspect}" }
      task_job
    end

    def load_task_job
      job_id = params[:job_id]
      if job_id.blank?
        render_json_error('Job ID is required', :bad_request)
        return
      end
      @task_job = find_task_job(job_id)
      return if @task_job
      render_json_error("Task job #{job_id} not found", :not_found)
    end

    def task_job_status(task_job)
      {
        job_id: task_job.job_id,
        kind: 'task',
        status: task_job.status,
        submitted_at: task_job.submitted_at,
        completed_at: task_job.completed_at,
        duration: task_job.duration,
        task_name: task_job.task_name,
        task_description: task_job.task_description,
        task_parameters: task_job.task_parameters,
        targets: task_job.targets,
        smart_proxy: {
          id: task_job.smart_proxy_id,
          name: task_job.smart_proxy&.name || '(unknown)',
        },
      }
    end

    def task_job_result(task_job)
      {
        kind: 'task',
        status: task_job.status,
        command: task_job.command,
        value: task_job.result,
        log: task_job.log,
      }
    end

    def paginated_task_jobs(per_page_param:, page:)
      per_page = if per_page_param == 'all'
                   [ForemanOpenbolt::TaskJob.count, 1].max
                 elsif per_page_param.present?
                   per_page_param.to_i.clamp(1, 100)
                 else
                   20
                 end
      ForemanOpenbolt::TaskJob.includes(:smart_proxy).recent.paginate(page: page, per_page: per_page)
    end

    def job_status
      render json: task_job_status(@task_job)
    end

    def job_result
      render json: task_job_result(@task_job)
    end

    def jobs
      paginated = paginated_task_jobs(per_page_param: params[:per_page], page: params[:page])

      render json: {
        total: paginated.total_entries,
        page: paginated.current_page,
        per_page: paginated.per_page,
        results: paginated.map { |job| task_job_status(job) },
      }
    end
  end
end
