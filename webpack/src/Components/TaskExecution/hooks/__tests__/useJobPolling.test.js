import { renderHook, act } from '@testing-library/react-hooks';
import { API } from 'foremanReact/redux/API';
import useJobPolling from '../useJobPolling';

jest.useFakeTimers();

afterEach(() => {
  jest.clearAllMocks();
  jest.clearAllTimers();
});

describe('useJobPolling', () => {
  test('returns initial pending state and does not poll when jobId is null', () => {
    const { result } = renderHook(() => useJobPolling(null));
    expect(result.current.status).toBe('pending');
    expect(result.current.isPolling).toBe(false);
    expect(result.current.result).toBeNull();
  });

  test('polls for status and completes when job succeeds', async () => {
    const statusData = {
      status: 'success',
      submitted_at: '2026-01-01T00:00:00Z',
      completed_at: '2026-01-01T00:01:00Z',
      task_name: 'test::task',
      task_description: 'A test task',
      task_parameters: { name: 'nginx' },
      targets: ['host1.example.com'],
      smart_proxy: { id: 1, name: 'proxy1' },
    };
    const resultData = {
      command: 'bolt task run test::task',
      value: { items: [{ status: 'success' }] },
      log: 'Task completed',
    };

    API.get
      .mockResolvedValueOnce({ data: statusData })
      .mockResolvedValueOnce({ data: resultData });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-123'));
      // Let the poll promise resolve
      await new Promise(resolve => setImmediate(resolve));
    });

    const { result } = hookResult;
    expect(result.current.status).toBe('success');
    expect(result.current.taskName).toBe('test::task');
    expect(result.current.targets).toEqual(['host1.example.com']);
    expect(result.current.result).toEqual({
      command: 'bolt task run test::task',
      result: { items: [{ status: 'success' }] },
      log: 'Task completed',
    });
    expect(result.current.isPolling).toBe(false);
  });

  test('does not fetch result for INVALID status', async () => {
    const statusData = {
      status: 'invalid',
      task_name: 'broken::task',
      targets: [],
    };

    API.get.mockResolvedValueOnce({ data: statusData });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-456'));
      await new Promise(resolve => setImmediate(resolve));
    });

    const { result } = hookResult;
    expect(result.current.status).toBe('invalid');
    expect(result.current.result).toBeNull();
    // Only one API call (status), no result fetch
    expect(API.get).toHaveBeenCalledTimes(1);
  });

  test('sets error when status endpoint fails', async () => {
    API.get.mockRejectedValueOnce({ message: 'Connection refused' });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-789'));
      await new Promise(resolve => setImmediate(resolve));
    });

    const { result } = hookResult;
    expect(result.current.error).toContain('Connection refused');
    expect(result.current.isPolling).toBe(false);
  });

  test('handles result fetch failure gracefully', async () => {
    const statusData = {
      status: 'success',
      task_name: 'test::task',
      targets: [],
    };

    API.get
      .mockResolvedValueOnce({ data: statusData })
      .mockRejectedValueOnce({ message: 'Result unavailable' });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-fail'));
      await new Promise(resolve => setImmediate(resolve));
    });

    const { result } = hookResult;
    expect(result.current.status).toBe('success');
    expect(result.current.error).toContain('Result unavailable');
    expect(result.current.result).toEqual({ result: null, log: '' });
  });

  test('cancels polling on unmount', async () => {
    const statusData = {
      status: 'running',
      task_name: 'long::task',
      targets: [],
    };
    API.get.mockResolvedValue({ data: statusData });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-cancel'));
      await new Promise(resolve => setImmediate(resolve));
    });

    // Unmount while still polling
    hookResult.unmount();

    // Advance timers past the polling interval
    jest.advanceTimersByTime(10000);

    // API should have been called once for the initial poll, not more
    const callCount = API.get.mock.calls.length;
    jest.advanceTimersByTime(10000);
    expect(API.get.mock.calls).toHaveLength(callCount);
  });

  test('loads metadata only once across multiple polls', async () => {
    API.get
      .mockResolvedValueOnce({
        data: { status: 'running', task_name: 'my::task', targets: ['host1'] },
      })
      .mockResolvedValueOnce({
        data: {
          status: 'success',
          task_name: 'changed::name',
          targets: ['host2'],
        },
      })
      .mockResolvedValueOnce({
        data: { command: 'bolt', value: {}, log: '' },
      });

    let hookResult;
    await act(async () => {
      hookResult = renderHook(() => useJobPolling('job-meta'));
      // First poll resolves (running)
      await new Promise(resolve => setImmediate(resolve));
      // Advance past the polling interval
      jest.advanceTimersByTime(5000);
      // Second poll resolves (success) + result fetch
      await new Promise(resolve => setImmediate(resolve));
    });

    const { result } = hookResult;
    // Task name should be from the first poll, not the second
    expect(result.current.taskName).toBe('my::task');
    expect(result.current.targets).toEqual(['host1']);
  });
});
