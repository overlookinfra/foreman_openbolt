import React from 'react';
import { renderHook } from '@testing-library/react-hooks';
import { Provider } from 'react-redux';
import { createStore } from 'redux';
import { API } from 'foremanReact/redux/API';
import { addToast } from 'foremanReact/components/ToastsList';
import { useSmartProxies } from '../useSmartProxies';

const mockStore = createStore(() => ({}));
const wrapper = ({ children }) => (
  <Provider store={mockStore}>{children}</Provider>
);

afterEach(() => {
  jest.clearAllMocks();
});

describe('useSmartProxies', () => {
  test('fetches proxies on mount and returns results', async () => {
    const proxies = [
      { id: 1, name: 'proxy1' },
      { id: 2, name: 'proxy2' },
    ];
    API.get.mockResolvedValue({ data: { results: proxies } });

    const { result, waitForNextUpdate } = renderHook(() => useSmartProxies(), {
      wrapper,
    });

    expect(result.current.isLoadingProxies).toBe(true);

    await waitForNextUpdate();

    expect(result.current.isLoadingProxies).toBe(false);
    expect(result.current.smartProxies).toEqual(proxies);
    expect(API.get).toHaveBeenCalledWith(
      expect.stringContaining('/api/smart_proxies')
    );
  });

  test('returns empty array when no proxies found', async () => {
    API.get.mockResolvedValue({ data: { results: [] } });

    const { result, waitForNextUpdate } = renderHook(() => useSmartProxies(), {
      wrapper,
    });
    await waitForNextUpdate();

    expect(result.current.smartProxies).toEqual([]);
  });

  test('handles fetch error and shows toast', async () => {
    API.get.mockRejectedValue({ message: 'Network error' });

    const { result, waitForNextUpdate } = renderHook(() => useSmartProxies(), {
      wrapper,
    });
    await waitForNextUpdate();

    expect(result.current.isLoadingProxies).toBe(false);
    expect(result.current.smartProxies).toEqual([]);
    expect(addToast).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'danger',
        message: expect.stringContaining('Failed to load Smart Proxies'),
      })
    );
  });
});
