// Exported so tests can use the launch wire format
export const buildLaunchPayload = ({
  proxyId,
  taskName,
  targets,
  hostGroups,
  parameters,
  options,
}) => ({
  smart_proxy_id: proxyId,
  task_name: taskName,
  targets: targets.join(','),
  host_groups: hostGroups.join(','),
  parameters,
  options,
});
