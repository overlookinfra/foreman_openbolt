import React from 'react';

const TaskSelector = ({
  tasks,
  value,
  loading,
  disabled,
  onChange,
  onReload
}) => (
  <div className="form-group">
    <label htmlFor="task_select" className="col-md-2 control-label">
      Task Name
    </label>
    <div className="col-md-6" style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
      <select
        id="task_select"
        name="task_name"
        className="form-control"
        disabled={disabled || loading}
        value={value}
        onChange={e => onChange(e.target.value)}
        aria-required="true"
      >
        <option value="">
          {loading ? "Loading tasks..." : "Select a task"}
        </option>
        {!loading && tasks.map(t => (
          <option key={t} value={t}>{t}</option>
        ))}
      </select>
      <button
        type="button"
        id="reload_tasks"
        className="btn btn-default"
        disabled={disabled || loading}
        title="Reload tasks from Bolt. This may take some time."
        aria-label="Reload tasks from Bolt. This may take some time."
        onClick={onReload}
      >
        <span className="pficon pficon-restart" aria-hidden="true"></span>
      </button>
    </div>
  </div>
);

export default TaskSelector;
