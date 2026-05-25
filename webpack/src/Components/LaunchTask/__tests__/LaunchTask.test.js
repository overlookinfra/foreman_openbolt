import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { MemoryRouter } from 'react-router-dom';
import { API } from 'foremanReact/redux/API';
import LaunchTask, { buildLaunchPayload } from '../index';

// Mock HostSelector to avoid Apollo/GraphQL dependency chain
jest.mock('../HostSelector', () => {
  const MockHostSelector = () => (
    <div data-testid="host-selector">Host Selector</div>
  );
  MockHostSelector.displayName = 'HostSelector';
  return MockHostSelector;
});

const mockStore = createStore(() => ({}));

const renderLaunchTask = () =>
  render(
    <Provider store={mockStore}>
      <MemoryRouter>
        <LaunchTask />
      </MemoryRouter>
    </Provider>
  );

afterEach(() => {
  jest.clearAllMocks();
});

describe('LaunchTask', () => {
  beforeEach(() => {
    // useSmartProxies fetches on mount
    API.get.mockResolvedValue({
      data: {
        results: [
          { id: 1, name: 'proxy-one' },
          { id: 2, name: 'proxy-two' },
        ],
      },
    });
  });

  test('renders the form with Launch Task button', async () => {
    renderLaunchTask();
    await waitFor(() => {
      expect(screen.getByText(/Launch Task/)).toBeInTheDocument();
    });
  });

  test('renders Smart Proxy select with fetched proxies', async () => {
    renderLaunchTask();
    await waitFor(() => {
      expect(screen.getByText('proxy-one')).toBeInTheDocument();
      expect(screen.getByText('proxy-two')).toBeInTheDocument();
    });
  });

  test('Launch Task button is disabled when form is incomplete', async () => {
    renderLaunchTask();
    await waitFor(() => {
      const button = screen.getByRole('button', { name: /Launch Task/ });
      expect(button).toBeDisabled();
    });
  });

  test('shows task select as disabled before proxy is selected', async () => {
    renderLaunchTask();
    await waitFor(() => {
      const taskSelect = screen.getByLabelText('Select Task');
      expect(taskSelect).toBeDisabled();
    });
  });

  test('renders host selector', async () => {
    renderLaunchTask();
    await waitFor(() => {
      expect(screen.getByTestId('host-selector')).toBeInTheDocument();
    });
  });
});

describe('buildLaunchPayload', () => {
  // Pins the wire-format contract with the controller and the smart proxy.
  // The controller reads `params[:parameters]` and the proxy reads the
  // `"parameters"` JSON key. Renaming this client-side to `params:` (a
  // tempting symmetry with Rails' `params`) would let task launches succeed
  // with silently empty parameters because nothing on the server side would
  // error out. The proxy would just receive an unknown key and ignore it.
  test('uses "parameters" key for task parameters, not "params"', () => {
    const body = buildLaunchPayload({
      proxyId: 1,
      taskName: 'mymod::install',
      targets: ['host1.example.com'],
      parameters: { name: 'nginx', version: '1.21' },
      options: { transport: 'ssh' },
    });

    expect(body).toHaveProperty('parameters', {
      name: 'nginx',
      version: '1.21',
    });
    expect(body).not.toHaveProperty('params');
  });

  test('joins targets with comma into a single string', () => {
    const body = buildLaunchPayload({
      proxyId: 1,
      taskName: 'mymod::install',
      targets: ['host1', 'host2', 'host3'],
      parameters: {},
      options: {},
    });

    expect(body.targets).toBe('host1,host2,host3');
  });

  test('forwards smart_proxy_id, task_name, and options unchanged', () => {
    const body = buildLaunchPayload({
      proxyId: 42,
      taskName: 'puppet_conf::set',
      targets: ['host1'],
      parameters: {},
      options: { transport: 'choria', 'run-as': 'root' },
    });

    expect(body.smart_proxy_id).toBe(42);
    expect(body.task_name).toBe('puppet_conf::set');
    expect(body.options).toEqual({ transport: 'choria', 'run-as': 'root' });
  });
});
