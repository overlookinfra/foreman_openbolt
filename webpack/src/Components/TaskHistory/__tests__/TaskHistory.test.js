import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { API } from 'foremanReact/redux/API';
import { addToast } from 'foremanReact/components/ToastsList';
import TaskHistory from '../index';

const mockStore = createStore(() => ({}));
const wrapper = ({ children }) => (
  <Provider store={mockStore}>{children}</Provider>
);

afterEach(() => {
  jest.clearAllMocks();
});

const sampleJobs = [
  {
    job_id: 'job-1',
    task_name: 'mymod::install',
    task_description: 'Install a package',
    task_parameters: { name: 'nginx' },
    status: 'success',
    targets: ['host1.example.com'],
    submitted_at: '2026-01-15T10:00:00Z',
    completed_at: '2026-01-15T10:01:00Z',
    duration: 60,
  },
  {
    job_id: 'job-2',
    task_name: 'mymod::mytask',
    task_description: 'Restart a service',
    task_parameters: {},
    status: 'running',
    targets: ['host2.example.com'],
    submitted_at: '2026-01-15T11:00:00Z',
    completed_at: null,
    duration: null,
  },
];

describe('TaskHistory', () => {
  test('shows loading spinner initially', () => {
    API.get.mockReturnValue(new Promise(() => {}));
    render(<TaskHistory />, { wrapper });
    expect(screen.getByLabelText('Loading task history')).toBeInTheDocument();
  });

  test('renders task history table with jobs', async () => {
    API.get.mockResolvedValue({
      data: { results: sampleJobs, total: 2 },
    });

    render(<TaskHistory />, { wrapper });

    await waitFor(() => {
      expect(screen.getByText('mymod::install')).toBeInTheDocument();
    });
    expect(screen.getByText('mymod::mytask')).toBeInTheDocument();
    expect(screen.getByText('success')).toBeInTheDocument();
    expect(screen.getByText('running')).toBeInTheDocument();
  });

  test('shows empty state when no jobs exist', async () => {
    API.get.mockResolvedValue({
      data: { results: [], total: 0 },
    });

    render(<TaskHistory />, { wrapper });

    await waitFor(() => {
      expect(screen.getByText('No task history found')).toBeInTheDocument();
    });
  });

  test('shows toast and stops loading when API call fails', async () => {
    API.get.mockRejectedValue({ message: 'Network error' });

    render(<TaskHistory />, { wrapper });

    await waitFor(() => {
      expect(
        screen.queryByLabelText('Loading task history')
      ).not.toBeInTheDocument();
    });
    expect(addToast).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'danger',
        message: expect.stringContaining('Failed to load task history'),
      })
    );
  });

  test('calls API with page and per_page params', async () => {
    API.get.mockResolvedValue({
      data: { results: [], total: 0 },
    });

    render(<TaskHistory />, { wrapper });

    await waitFor(() => {
      expect(API.get).toHaveBeenCalledWith(expect.stringContaining('page=1'));
      expect(API.get).toHaveBeenCalledWith(
        expect.stringContaining('per_page=20')
      );
    });
  });
});
