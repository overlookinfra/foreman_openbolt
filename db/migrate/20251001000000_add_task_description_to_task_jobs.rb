# frozen_string_literal: true

class AddTaskDescriptionToTaskJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :openbolt_task_jobs, :task_description, :text
  end
end
