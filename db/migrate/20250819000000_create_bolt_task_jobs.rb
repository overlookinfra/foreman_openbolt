# frozen_string_literal: true

class CreateBoltTaskJobs < ActiveRecord::Migration[6.1]
  def change
    create_table :bolt_task_jobs, id: false do |t|
      t.string :job_id, null: false, primary_key: true
      t.references :smart_proxy, null: false, foreign_key: true, index: true
      t.string :task_name, null: false
      t.string :status, null: false, default: 'pending'

      # JSON columns for complex data
      t.jsonb :targets, default: []
      t.jsonb :task_parameters, default: {}
      t.jsonb :bolt_options, default: {}
      t.jsonb :result

      t.text :log

      t.datetime :submitted_at, null: false, index: true
      t.datetime :completed_at

      t.timestamps
    end
  end
end
