# frozen_string_literal: true

class AddCommandToOpenboltTaskJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :openbolt_task_jobs, :command, :string
  end
end