import {
  extractErrorMessage,
  displayValue,
  formatDuration,
  formatDate,
} from '../helpers';

describe('extractErrorMessage', () => {
  test('extracts error from response.data.error', () => {
    const error = { response: { data: { error: 'Proxy unreachable' } } };
    expect(extractErrorMessage(error)).toBe('Proxy unreachable');
  });

  test('extracts error from response.data.error when error is an object with message', () => {
    const error = { response: { data: { error: { message: 'Bad request' } } } };
    expect(extractErrorMessage(error)).toBe('Bad request');
  });

  test('stringifies object error without message key', () => {
    const errorObj = { code: 500, detail: 'internal' };
    const error = { response: { data: { error: errorObj } } };
    expect(extractErrorMessage(error)).toBe(JSON.stringify(errorObj));
  });

  test('falls back to error.message', () => {
    const error = { message: 'Network error' };
    expect(extractErrorMessage(error)).toBe('Network error');
  });

  test('returns Unknown error when no useful fields exist', () => {
    const error = {};
    expect(extractErrorMessage(error)).toBe('Unknown error');
  });

  test('returns Unknown error for null input', () => {
    expect(extractErrorMessage(null)).toBe('Unknown error');
  });

  test('returns Unknown error for undefined input', () => {
    expect(extractErrorMessage(undefined)).toBe('Unknown error');
  });
});

describe('displayValue', () => {
  test('returns dash for null', () => {
    expect(displayValue(null)).toBe('-');
  });

  test('returns dash for undefined', () => {
    expect(displayValue(undefined)).toBe('-');
  });

  test('returns JSON string for objects', () => {
    expect(displayValue({ key: 'val' })).toBe('{"key":"val"}');
  });

  test('returns string representation for numbers', () => {
    expect(displayValue(42)).toBe('42');
  });

  test('returns string as-is', () => {
    expect(displayValue('hello')).toBe('hello');
  });

  test('returns string for boolean', () => {
    expect(displayValue(true)).toBe('true');
  });

  test('returns empty string as-is (not dash)', () => {
    expect(displayValue('')).toBe('');
  });
});

describe('formatDuration', () => {
  test('returns dash for null', () => {
    expect(formatDuration(null)).toBe('-');
  });

  test('returns dash for undefined', () => {
    expect(formatDuration(undefined)).toBe('-');
  });

  test('returns 0s for zero', () => {
    expect(formatDuration(0)).toBe('0s');
  });

  test('returns dash for negative', () => {
    expect(formatDuration(-5)).toBe('-');
  });

  test('formats seconds only', () => {
    expect(formatDuration(45)).toBe('45s');
  });

  test('formats minutes and seconds', () => {
    expect(formatDuration(125)).toBe('2m 5s');
  });

  test('formats hours, minutes, and seconds', () => {
    expect(formatDuration(3661)).toBe('1h 1m 1s');
  });

  test('formats exact minute boundary', () => {
    expect(formatDuration(60)).toBe('1m 0s');
  });

  test('formats exact hour boundary', () => {
    expect(formatDuration(3600)).toBe('1h 0m 0s');
  });

  test('rounds fractional seconds', () => {
    expect(formatDuration(45.7)).toBe('46s');
  });
});

describe('formatDate', () => {
  test('returns dash for null', () => {
    expect(formatDate(null)).toBe('-');
  });

  test('returns dash for empty string', () => {
    expect(formatDate('')).toBe('-');
  });

  test('returns dash for invalid date string', () => {
    expect(formatDate('not-a-date')).toBe('-');
  });

  test('formats a valid ISO date with recognizable date components', () => {
    const result = formatDate('2026-01-15T10:30:00Z');
    expect(result).not.toBe('-');
    expect(result).toMatch(/2026/);
    expect(result).toMatch(/15/);
  });
});
