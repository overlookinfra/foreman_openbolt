import React from 'react';
import { renderHook, act } from '@testing-library/react-hooks';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { API } from 'foremanReact/redux/API';
import { addToast } from 'foremanReact/components/ToastsList';
import { useOpenBoltOptions } from '../useOpenBoltOptions';

const mockStore = createStore(() => ({}));
const wrapper = ({ children }) => (
  <Provider store={mockStore}>{children}</Provider>
);

afterEach(() => {
  jest.clearAllMocks();
});

describe('useOpenBoltOptions', () => {
  test('returns null and does not call API when proxyId is falsy', async () => {
    const { result } = renderHook(() => useOpenBoltOptions(), { wrapper });

    let returnValue;
    await act(async () => {
      returnValue = await result.current.fetchOpenBoltOptions(null);
    });

    expect(returnValue).toBeNull();
    expect(API.get).not.toHaveBeenCalled();
  });

  test('fetches options and extracts defaults', async () => {
    const options = {
      transport: { type: 'string', default: 'ssh' },
      user: { type: 'string' },
      verbose: { type: 'boolean', default: false },
    };
    API.get.mockResolvedValue({ data: options });

    const { result } = renderHook(() => useOpenBoltOptions(), { wrapper });

    await act(async () => {
      await result.current.fetchOpenBoltOptions(42);
    });

    expect(result.current.openBoltOptionsMetadata).toEqual(options);
    expect(result.current.openBoltOptions).toEqual({
      transport: 'ssh',
      verbose: false,
    });
    expect(result.current.openBoltOptions.verbose).toBe(false);
    expect(result.current.openBoltOptions.user).toBeUndefined();
  });

  test('resets state before fetching', async () => {
    API.get.mockResolvedValue({ data: { transport: { default: 'ssh' } } });

    const { result } = renderHook(() => useOpenBoltOptions(), { wrapper });

    await act(async () => {
      await result.current.fetchOpenBoltOptions(1);
    });
    expect(result.current.openBoltOptions).toEqual({ transport: 'ssh' });

    API.get.mockResolvedValue({ data: { user: { default: 'root' } } });
    await act(async () => {
      await result.current.fetchOpenBoltOptions(2);
    });
    expect(result.current.openBoltOptions).toEqual({ user: 'root' });
    expect(result.current.openBoltOptions.transport).toBeUndefined();
  });

  test('handles errors and shows toast', async () => {
    API.get.mockRejectedValue({ message: 'Connection refused' });

    const { result } = renderHook(() => useOpenBoltOptions(), { wrapper });

    let returnValue;
    await act(async () => {
      returnValue = await result.current.fetchOpenBoltOptions(42);
    });

    expect(returnValue).toBeNull();
    expect(result.current.isLoadingOptions).toBe(false);
    expect(addToast).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'danger',
        message: expect.stringContaining('Failed to load OpenBolt options'),
      })
    );
  });
});
