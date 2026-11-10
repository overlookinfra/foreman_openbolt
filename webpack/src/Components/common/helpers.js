import { useCallback } from 'react';
import { useDispatch } from 'react-redux';
import { addToast } from 'foremanReact/components/ToastsList';
import { translate as __ } from 'foremanReact/common/I18n';

export const useShowMessage = () => {
  const dispatch = useDispatch();

  return useCallback(
    (message, type = 'danger') => {
      dispatch(addToast({ type, message }));
    },
    [dispatch]
  );
};

export const extractErrorMessage = error => {
  if (!error) return __('Unknown error');
  const rawError =
    error.response?.data?.error || error.message || __('Unknown error');
  if (typeof rawError === 'object')
    return rawError.message || JSON.stringify(rawError);
  return rawError;
};

export const displayValue = value => {
  if (value === null || value === undefined) return '-';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
};

export const formatDuration = duration => {
  if (duration === null || duration === undefined || duration < 0) return '-';
  const totalSeconds = Math.round(duration);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
};

export const formatDate = dateString => {
  if (!dateString) return '-';
  const date = new Date(dateString);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString();
};

export const enumStringToArray = input => {
  const m = input.match(/^Enum\s*\[(.*)\]\s*$/i);
  if (!m) return input;

  const body = m[1];
  const result = [];
  let current = '';
  let quote = null;

  for (let i = 0; i < body.length; i++) {
    const ch = body[i];

    if (ch === "'" || ch === '"') {
      if (quote === ch) quote = null;
      else if (!quote) quote = ch;
      current += ch;
      // eslint-disable-next-line no-continue
      continue;
    }

    if (ch === ',' && !quote) {
      result.push(cleanToken(current));
      current = '';
    } else {
      current += ch;
    }
  }

  if (current.length || body.endsWith(',')) {
    result.push(cleanToken(current));
  }

  return result;
}

function cleanToken(token) {
  token = token.trim();
  if (
      (token.startsWith("'") && token.endsWith("'")) ||
      (token.startsWith('"') && token.endsWith('"'))
  ) {
    token = token.slice(1, -1);
  }
  return token;
}
