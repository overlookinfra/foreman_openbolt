// Mock for Foreman's toast notification system. Uses jest.fn() so tests
// can assert that error/success toasts are dispatched correctly.
export const addToast = jest.fn(toast => ({
  type: 'ADD_TOAST',
  payload: toast,
}));
