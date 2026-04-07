import React from 'react';
import { render, screen } from '@testing-library/react';
import ExecutionDisplay from '../ExecutionDisplay';

const defaultProps = {
  smartProxy: { id: 1, name: 'proxy1' },
  jobId: 'job-123',
  jobStatus: 'running',
  isPolling: true,
  targets: ['host1.example.com'],
  submittedAt: '2026-01-15T10:30:00Z',
  completedAt: null,
  taskName: 'test::task',
  taskDescription: 'A test task',
  taskParameters: { name: 'nginx' },
};

describe('ExecutionDisplay', () => {
  test('renders both tab titles', () => {
    render(<ExecutionDisplay {...defaultProps} />);
    expect(screen.getByText('Execution Details')).toBeInTheDocument();
    expect(screen.getByText('Task Details')).toBeInTheDocument();
  });

  test('renders execution details content by default', () => {
    render(<ExecutionDisplay {...defaultProps} />);
    expect(screen.getByText('job-123')).toBeInTheDocument();
  });
});
