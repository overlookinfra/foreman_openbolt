import { buildLaunchPayload } from '../helpers';

describe('buildLaunchPayload', () => {
  test('passes "parameters" key through correctly', () => {
    const body = buildLaunchPayload({
      proxyId: 1,
      taskName: 'mymod::install',
      targets: ['host1.example.com'],
      hostGroups: [],
      parameters: { name: 'nginx', version: '1.21' },
      options: { transport: 'ssh' },
    });

    expect(body).toHaveProperty('parameters', {
      name: 'nginx',
      version: '1.21',
    });
  });

  test('joins targets with comma into a single string', () => {
    const body = buildLaunchPayload({
      proxyId: 1,
      taskName: 'mymod::install',
      targets: ['host1', 'host2', 'host3'],
      hostGroups: [],
      parameters: {},
      options: {},
    });

    expect(body.targets).toBe('host1,host2,host3');
  });

  test('joins host groups with comma into a single string', () => {
    const body = buildLaunchPayload({
      proxyId: 1,
      taskName: 'mymod::install',
      targets: ['host1', 'host2', 'host3'],
      hostGroups: ['webservers', 'debian'],
      parameters: {},
      options: {},
    });

    expect(body.host_groups).toBe('webservers,debian');
  });

  test('forwards smart_proxy_id, task_name, and options unchanged', () => {
    const body = buildLaunchPayload({
      proxyId: 42,
      taskName: 'puppet_conf::set',
      targets: ['host1'],
      hostGroups: [],
      parameters: {},
      options: { transport: 'choria', 'run-as': 'root' },
    });

    expect(body.smart_proxy_id).toBe(42);
    expect(body.task_name).toBe('puppet_conf::set');
    expect(body.options).toEqual({ transport: 'choria', 'run-as': 'root' });
  });
});
