import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import TaskSelect from '../TaskSelect';

const defaultProps = {
  taskNames: ['mymod::install', 'mymod::mytask'],
  selectedTask: '',
  onTaskChange: jest.fn(),
  onReloadTasks: jest.fn(),
  isLoading: false,
  isDisabled: false,
};

describe('TaskSelect', () => {
  test('renders task options', () => {
    render(<TaskSelect {...defaultProps} />);
    expect(screen.getByText('mymod::install')).toBeInTheDocument();
    expect(screen.getByText('mymod::mytask')).toBeInTheDocument();
  });

  test('shows loading placeholder when loading', () => {
    render(<TaskSelect {...defaultProps} isLoading />);
    expect(screen.getByText('Loading...')).toBeInTheDocument();
  });

  test('disables select and button when disabled', () => {
    const { container } = render(<TaskSelect {...defaultProps} isDisabled />);
    const select = container.querySelector('select');
    expect(select).toBeDisabled();
  });

  test('calls onReloadTasks when reload button is clicked', () => {
    const handleReload = jest.fn();
    render(<TaskSelect {...defaultProps} onReloadTasks={handleReload} />);
    const reloadButton = screen.getByLabelText('Reload tasks from OpenBolt');
    fireEvent.click(reloadButton);
    expect(handleReload).toHaveBeenCalled();
  });
});
