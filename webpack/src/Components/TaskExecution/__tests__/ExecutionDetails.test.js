import React from 'react';
import { render, screen } from '@testing-library/react';
import ExecutionDetails from '../ExecutionDetails';

const defaultProps = {
  smartProxy: { id: 1, name: 'test-proxy' },
  jobId: 'job-abc-123',
  jobStatus: 'running',
  isPolling: true,
  targets: ['host1.example.com', 'host2.example.com'],
  submittedAt: '2026-01-15T10:30:00Z',
  completedAt: null,
};

describe('ExecutionDetails', () => {
  test('renders job ID', () => {
    render(<ExecutionDetails {...defaultProps} />);
    expect(screen.getByText('job-abc-123')).toBeInTheDocument();
  });

  test('renders smart proxy name as link', () => {
    render(<ExecutionDetails {...defaultProps} />);
    const link = screen.getByText('test-proxy');
    expect(link).toBeInTheDocument();
    expect(link.closest('a')).toHaveAttribute('href', '/smart_proxies/1');
  });

  test('renders unknown proxy when smartProxy is null', () => {
    render(<ExecutionDetails {...defaultProps} smartProxy={null} />);
    expect(screen.getByText('Unknown')).toBeInTheDocument();
  });

  test('renders status label', () => {
    render(<ExecutionDetails {...defaultProps} jobStatus="success" />);
    expect(screen.getByText('Success')).toBeInTheDocument();
  });

  test('shows polling indicator when polling', () => {
    render(<ExecutionDetails {...defaultProps} isPolling />);
    expect(screen.getByText(/Updating every 5 seconds/)).toBeInTheDocument();
  });

  test('renders target count via HostsPopover', () => {
    render(<ExecutionDetails {...defaultProps} />);
    expect(screen.getByText('2')).toBeInTheDocument();
  });
});
