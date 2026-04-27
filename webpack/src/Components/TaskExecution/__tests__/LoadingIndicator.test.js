import React from 'react';
import { render, screen } from '@testing-library/react';
import LoadingIndicator from '../LoadingIndicator';

describe('LoadingIndicator', () => {
  test('shows running status message for running jobs', () => {
    render(<LoadingIndicator jobStatus="running" />);
    expect(screen.getByText(/running/i)).toBeInTheDocument();
  });

  test('shows current status message for pending jobs', () => {
    render(<LoadingIndicator jobStatus="pending" />);
    expect(screen.getByText(/pending/i)).toBeInTheDocument();
  });

  test('shows processing message for non-running statuses', () => {
    render(<LoadingIndicator jobStatus="success" />);
    expect(screen.getByText('Processing task results...')).toBeInTheDocument();
  });

  test('renders with status role for accessibility', () => {
    render(<LoadingIndicator jobStatus="running" />);
    expect(screen.getByRole('status')).toBeInTheDocument();
  });
});
