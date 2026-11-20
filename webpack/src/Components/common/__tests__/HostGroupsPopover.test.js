import React from 'react';
import { render, screen } from '@testing-library/react';
import HostGroupsPopover from '../HostGroupsPopover';

describe('HostGroupsPopover', () => {
  test('shows "No host groups specified" when hostGroups is empty', () => {
    render(<HostGroupsPopover hostGroups={[]} />);
    expect(screen.getByText('No host groups specified')).toBeInTheDocument();
  });

  test('shows "No host groups specified" when hostGroups is not provided', () => {
    render(<HostGroupsPopover />);
    expect(screen.getByText('No host groups specified')).toBeInTheDocument();
  });

  test('shows host groups count as button when hostGroups exist', () => {
    render(<HostGroupsPopover hostGroups={['webserver', 'nginx', 'php']} />);
    expect(screen.getByText('3')).toBeInTheDocument();
  });
});
