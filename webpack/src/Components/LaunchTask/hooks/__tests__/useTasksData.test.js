import React from 'react';
import { renderHook, act } from '@testing-library/react-hooks';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { API } from 'foremanReact/redux/API';
import { addToast } from 'foremanReact/components/ToastsList';
import { useTasksData } from '../useTasksData';

const mockStore = createStore(() => ({}));
const wrapper = ({ children }) => (
  <Provider store={mockStore}>{children}</Provider>
);

afterEach(() => {
  jest.clearAllMocks();
});

describe('useTasksData', () => {
  test('fetchTasks returns null and does not call API when proxyId is falsy', async () => {
    const { result } = renderHook(() => useTasksData(), { wrapper });

    let returnValue;
    await act(async () => {
      returnValue = await result.current.fetchTasks(null);
    });

    expect(returnValue).toBeNull();
    expect(API.get).not.toHaveBeenCalled();
  });

  test('fetchTasks fetches tasks from the normal endpoint', async () => {
    const tasks = { 'mymod::install': { description: 'Install a package' } };
    API.get.mockResolvedValue({ data: tasks });

    const { result } = renderHook(() => useTasksData(), { wrapper });

    await act(async () => {
      await result.current.fetchTasks(42);
    });

    expect(API.get).toHaveBeenCalledWith(
      expect.stringContaining('fetch_tasks')
    );
    expect(API.get).toHaveBeenCalledWith(
      expect.stringContaining('proxy_id=42')
    );
    expect(result.current.taskMetadata).toEqual(tasks);
    expect(result.current.isLoadingTasks).toBe(false);
  });

  test('fetchTasks uses reload endpoint when forceReload is true', async () => {
    API.get.mockResolvedValue({ data: {} });

    const { result } = renderHook(() => useTasksData(), { wrapper });

    await act(async () => {
      await result.current.fetchTasks(42, true);
    });

    expect(API.get).toHaveBeenCalledWith(
      expect.stringContaining('reload_tasks')
    );
  });

  test('fetchTasks resets state before fetching', async () => {
    API.get.mockResolvedValue({ data: { 'task::one': {} } });

    const { result } = renderHook(() => useTasksData(), { wrapper });

    // First fetch
    await act(async () => {
      await result.current.fetchTasks(1);
    });
    expect(Object.keys(result.current.taskMetadata)).toHaveLength(1);

    // Second fetch should reset
    API.get.mockResolvedValue({ data: { 'task::two': {}, 'task::three': {} } });
    await act(async () => {
      await result.current.fetchTasks(2);
    });
    expect(Object.keys(result.current.taskMetadata)).toHaveLength(2);
  });

  test('fetchTasks handles errors and shows toast', async () => {
    API.get.mockRejectedValue({ message: 'Network error' });

    const { result } = renderHook(() => useTasksData(), { wrapper });

    let returnValue;
    await act(async () => {
      returnValue = await result.current.fetchTasks(42);
    });

    expect(returnValue).toBeNull();
    expect(result.current.isLoadingTasks).toBe(false);
    expect(addToast).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'danger',
        message: expect.stringContaining('Failed to load tasks'),
      })
    );
  });
});
