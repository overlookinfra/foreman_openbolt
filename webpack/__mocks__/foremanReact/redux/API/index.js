// Mock for Foreman's API wrapper. Uses jest.fn() so tests can stub
// responses with mockResolvedValue/mockRejectedValue and assert calls.
export const API = {
  get: jest.fn(),
  post: jest.fn(),
  put: jest.fn(),
  delete: jest.fn(),
  patch: jest.fn(),
};

export default API;
