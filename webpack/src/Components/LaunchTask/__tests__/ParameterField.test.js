import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import ParameterField from '../ParameterField';

describe('ParameterField', () => {
  test('renders text input for string type', () => {
    const { container } = render(
      <ParameterField
        name="username"
        metadata={{ type: 'String' }}
        value="admin"
        onChange={jest.fn()}
      />
    );
    const input = container.querySelector('input[type="text"]');
    expect(input).toBeInTheDocument();
    expect(input.value).toBe('admin');
  });

  test('renders password input for sensitive fields', () => {
    const { container } = render(
      <ParameterField
        name="password"
        metadata={{ type: 'String', sensitive: true }}
        value="secret"
        onChange={jest.fn()}
      />
    );
    const input = container.querySelector('input[type="password"]');
    expect(input).toBeInTheDocument();
  });

  test('renders checkbox for boolean type', () => {
    render(
      <ParameterField
        name="verbose"
        metadata={{ type: 'boolean' }}
        value
        onChange={jest.fn()}
      />
    );
    expect(screen.getByRole('checkbox')).toBeInTheDocument();
  });

  test('renders checkbox for Optional[Boolean] type', () => {
    render(
      <ParameterField
        name="noop"
        metadata={{ type: 'Optional[Boolean]' }}
        value={false}
        onChange={jest.fn()}
      />
    );
    expect(screen.getByRole('checkbox')).toBeInTheDocument();
  });

  test('renders select for array (enum) type', () => {
    const { container } = render(
      <ParameterField
        name="transport"
        metadata={{ type: ['ssh', 'winrm'] }}
        value="ssh"
        onChange={jest.fn()}
      />
    );
    const select = container.querySelector('select');
    expect(select).toBeInTheDocument();
    expect(screen.getByText('ssh')).toBeInTheDocument();
    expect(screen.getByText('winrm')).toBeInTheDocument();
  });

  test('calls onChange when value changes', () => {
    const handleChange = jest.fn();
    const { container } = render(
      <ParameterField
        name="username"
        metadata={{ type: 'String' }}
        value=""
        onChange={handleChange}
      />
    );
    const input = container.querySelector('input');
    fireEvent.change(input, { target: { value: 'new-value' } });
    expect(handleChange).toHaveBeenCalledWith('username', 'new-value');
  });

  test('shows empty field for encrypted default instead of the placeholder value', () => {
    const { container } = render(
      <ParameterField
        name="password"
        metadata={{
          type: 'String',
          sensitive: true,
          default: '[Use saved encrypted default]',
        }}
        onChange={jest.fn()}
      />
    );
    const input = container.querySelector('input[type="password"]');
    expect(input.value).toBe('');
  });

  test('shows encrypted placeholder when value matches placeholder', () => {
    const { container } = render(
      <ParameterField
        name="password"
        metadata={{
          type: 'String',
          sensitive: true,
          default: '[Use saved encrypted default]',
        }}
        value="[Use saved encrypted default]"
        onChange={jest.fn()}
      />
    );
    const input = container.querySelector('input[type="password"]');
    expect(input.value).toBe('[Use saved encrypted default]');
  });

  test('renders empty text input when value is undefined and no default', () => {
    const { container } = render(
      <ParameterField
        name="tmpdir"
        metadata={{ type: 'String' }}
        onChange={jest.fn()}
      />
    );
    const input = container.querySelector('input[type="text"]');
    expect(input.value).toBe('');
  });
});
