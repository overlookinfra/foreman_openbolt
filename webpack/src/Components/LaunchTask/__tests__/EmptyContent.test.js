import React from 'react';
import { render, screen } from '@testing-library/react';
import EmptyContent from '../EmptyContent';

describe('EmptyContent', () => {
  test('renders the title text', () => {
    render(<EmptyContent title="No items found" />);
    expect(screen.getByText('No items found')).toBeInTheDocument();
  });
});
