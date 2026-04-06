import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { MemoryRouter } from 'react-router-dom';
import { API } from 'foremanReact/redux/API';
import LaunchTask from '../index';

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
