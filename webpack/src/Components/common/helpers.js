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
  if (!duration || duration < 0) return '-';
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
  return new Date(dateString).toLocaleString();
};
