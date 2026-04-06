import React from 'react';
import { render, screen } from '@testing-library/react';
import TaskPopover from '../TaskPopover';

describe('TaskPopover', () => {
  test('renders task name as button', () => {
    render(<TaskPopover taskName="mymod::install" />);
    expect(screen.getByText('mymod::install')).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /mymod::install/ })
    ).toBeInTheDocument();
  });

  test('renders task name button with description and parameters provided', () => {
    render(
      <TaskPopover
        taskName="test::task"
        taskDescription="A test task"
        taskParameters={{ name: 'nginx' }}
      />
    );
    expect(
      screen.getByRole('button', { name: /test::task/ })
    ).toBeInTheDocument();
  });
});
