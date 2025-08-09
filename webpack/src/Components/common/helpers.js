import { useCallback } from 'react';
import { useDispatch } from 'react-redux';
import { addToast } from 'foremanReact/components/ToastsList';

/**
 * Custom hook to show messages using the Foreman Toast system.
 *
 * @returns {Function} A function that takes a message and type, and shows a toast message.
 */
export const useShowMessage = () => {
  const dispatch = useDispatch();

  return useCallback(
    (message, type = 'danger') => {
      dispatch(addToast({ type, message }));
    },
    [dispatch]
  );
};
