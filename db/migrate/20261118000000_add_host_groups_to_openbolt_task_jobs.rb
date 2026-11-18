# frozen_string_literal: true

class AddHostGroupsToOpenboltTaskJobs < ActiveRecord::Migration[6.1]
  def change
    add_column :openbolt_task_jobs, :host_groups, :jsonb, default: []
  end
end
