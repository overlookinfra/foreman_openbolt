import React from 'react';
import { render, screen } from '@testing-library/react';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { MemoryRouter } from 'react-router-dom';
import { API } from 'foremanReact/redux/API';
import TaskExecution from '../index';

const mockStore = createStore(() => ({}));

const renderWithProviders = (jobId = 'test-job-123') => {
  const initialEntry = jobId
    ? `/foreman_openbolt/page_task_execution?job_id=${jobId}`
    : '/foreman_openbolt/page_task_execution';

  return render(
    <Provider store={mockStore}>
      <MemoryRouter initialEntries={[initialEntry]}>
        <TaskExecution />
      </MemoryRouter>
    </Provider>
  );
};

afterEach(() => {
  jest.clearAllMocks();
});

describe('TaskExecution', () => {
  test('renders Run Another Task button', () => {
    API.get.mockReturnValue(new Promise(() => {}));
    renderWithProviders();
    expect(screen.getByText('Run Another Task')).toBeInTheDocument();
  });

  test('renders ExecutionDisplay with job details', () => {
    API.get.mockReturnValue(new Promise(() => {}));
    renderWithProviders();
    expect(screen.getByText('Execution Details')).toBeInTheDocument();
  });

  test('shows loading indicator while polling', () => {
    API.get.mockReturnValue(new Promise(() => {}));
    renderWithProviders();
    expect(screen.getByRole('status')).toBeInTheDocument();
  });

  test('returns null and redirects when job_id is missing', () => {
    const { container } = renderWithProviders(null);
    expect(container.innerHTML).toBe('');
  });

  test('strips ANSI codes from log output when result is available', async () => {
    const statusData = {
      status: 'success',
      task_name: 'test::task',
      targets: ['host1'],
      submitted_at: '2026-01-01T00:00:00Z',
      completed_at: '2026-01-01T00:01:00Z',
      smart_proxy: { id: 1, name: 'proxy1' },
    };
    const resultData = {
      command: 'bolt task run test::task',
      value: { items: [] },
      log: '\u001b[32mSuccess\u001b[0m: Task completed',
    };

    API.get
      .mockResolvedValueOnce({ data: statusData })
      .mockResolvedValueOnce({ data: resultData });

    renderWithProviders();

    // Wait for result to render, then verify ANSI codes are stripped
    await screen.findByText('Result');
    // The log should contain the clean text without ANSI escape sequences
    expect(screen.getByText(/Success: Task completed/)).toBeInTheDocument();
    expect(screen.queryByText(/\[32m/)).not.toBeInTheDocument();
  });
});
