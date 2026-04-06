import React from 'react';
import { render, screen } from '@testing-library/react';
import HostsPopover from '../HostsPopover';

describe('HostsPopover', () => {
  test('shows "No targets specified" when targets is empty', () => {
    render(<HostsPopover targets={[]} />);
    expect(screen.getByText('No targets specified')).toBeInTheDocument();
  });

  test('shows "No targets specified" when targets is not provided', () => {
    render(<HostsPopover />);
    expect(screen.getByText('No targets specified')).toBeInTheDocument();
  });

  test('shows target count as button when targets exist', () => {
    render(<HostsPopover targets={['host1.com', 'host2.com', 'host3.com']} />);
    expect(screen.getByText('3')).toBeInTheDocument();
  });
});
