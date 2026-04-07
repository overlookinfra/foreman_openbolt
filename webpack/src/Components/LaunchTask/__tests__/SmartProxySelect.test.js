import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import SmartProxySelect from '../SmartProxySelect';

const proxies = [
  { id: 1, name: 'proxy-one' },
  { id: 2, name: 'proxy-two' },
];

describe('SmartProxySelect', () => {
  test('renders proxy options', () => {
    render(
      <SmartProxySelect
        smartProxies={proxies}
        selectedProxy=""
        onProxyChange={jest.fn()}
        isLoading={false}
      />
    );
    expect(screen.getByText('proxy-one')).toBeInTheDocument();
    expect(screen.getByText('proxy-two')).toBeInTheDocument();
  });

  test('shows loading placeholder when loading', () => {
    render(
      <SmartProxySelect
        smartProxies={[]}
        selectedProxy=""
        onProxyChange={jest.fn()}
        isLoading
      />
    );
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  test('disables select when loading', () => {
    const { container } = render(
      <SmartProxySelect
        smartProxies={proxies}
        selectedProxy=""
        onProxyChange={jest.fn()}
        isLoading
      />
    );
    const select = container.querySelector('select');
    expect(select).toBeDisabled();
  });

  test('calls onProxyChange when selection changes', () => {
    const handleChange = jest.fn();
    const { container } = render(
      <SmartProxySelect
        smartProxies={proxies}
        selectedProxy=""
        onProxyChange={handleChange}
        isLoading={false}
      />
    );
    const select = container.querySelector('select');
    fireEvent.change(select, { target: { value: '1' } });
    expect(handleChange).toHaveBeenCalledWith(expect.anything(), '1');
  });
});
