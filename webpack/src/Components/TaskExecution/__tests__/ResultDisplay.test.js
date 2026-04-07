import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import ResultDisplay from '../ResultDisplay';

describe('ResultDisplay', () => {
  test('renders result JSON in the default tab', () => {
    const jobResult = { items: [{ status: 'success' }] };
    render(<ResultDisplay jobResult={jobResult} jobLog="" />);
    expect(screen.getByText('Result')).toBeInTheDocument();
    expect(screen.getByText(/items/)).toBeInTheDocument();
    expect(screen.getByText(/success/)).toBeInTheDocument();
  });

  test('renders log content when log tab is selected', () => {
    render(
      <ResultDisplay jobResult={{}} jobLog="Task finished successfully" />
    );
    fireEvent.click(screen.getByText('Log Output'));
    expect(screen.getByText('Task finished successfully')).toBeInTheDocument();
  });

  test('shows empty state when result is empty', () => {
    render(<ResultDisplay jobResult={{}} jobLog="" />);
    expect(
      screen.getByText('No result data returned from the task.')
    ).toBeInTheDocument();
  });
});
