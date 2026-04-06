import React from 'react';
import { render, screen } from '@testing-library/react';
import TaskDetails from '../TaskDetails';

describe('TaskDetails', () => {
  test('renders task name', () => {
    render(<TaskDetails taskName="mymod::install" />);
    expect(screen.getByText('mymod::install')).toBeInTheDocument();
  });

  test('renders description when provided', () => {
    render(
      <TaskDetails
        taskName="mymod::install"
        taskDescription="Install a system package"
      />
    );
    expect(screen.getByText('Install a system package')).toBeInTheDocument();
  });

  test('does not render description section when null', () => {
    render(<TaskDetails taskName="test::task" taskDescription={null} />);
    expect(screen.queryByText('Description')).not.toBeInTheDocument();
  });

  test('renders parameters table when parameters exist', () => {
    render(
      <TaskDetails
        taskName="test::task"
        taskParameters={{ name: 'nginx', version: '1.0' }}
      />
    );
    expect(screen.getByText('name')).toBeInTheDocument();
    expect(screen.getByText('nginx')).toBeInTheDocument();
    expect(screen.getByText('version')).toBeInTheDocument();
    expect(screen.getByText('1.0')).toBeInTheDocument();
  });
});
