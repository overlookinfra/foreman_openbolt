import React from 'react';
import { render, screen } from '@testing-library/react';
import ParametersSection from '../ParametersSection';

describe('ParametersSection', () => {
  test('shows empty state when no task is selected', () => {
    render(
      <ParametersSection
        selectedTask=""
        taskMetadata={{}}
        taskParameters={{}}
        onParameterChange={jest.fn()}
      />
    );
    expect(
      screen.getByText('Select a task to see parameters')
    ).toBeInTheDocument();
  });

  test('shows empty state when task has no parameters', () => {
    render(
      <ParametersSection
        selectedTask="test::task"
        taskMetadata={{ 'test::task': { parameters: {} } }}
        taskParameters={{}}
        onParameterChange={jest.fn()}
      />
    );
    expect(screen.getByText('This task has no parameters')).toBeInTheDocument();
  });

  test('renders parameter fields when task has parameters', () => {
    const metadata = {
      'test::task': {
        parameters: {
          name: { type: 'String', description: 'Package name' },
        },
      },
    };
    render(
      <ParametersSection
        selectedTask="test::task"
        taskMetadata={metadata}
        taskParameters={{ name: 'nginx' }}
        onParameterChange={jest.fn()}
      />
    );
    expect(screen.getByText('name')).toBeInTheDocument();
  });
});
