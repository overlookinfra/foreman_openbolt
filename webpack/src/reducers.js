import { combineReducers } from 'redux';
import EmptyStateReducer from './Components/EmptyState/EmptyStateReducer';

const reducers = {
  foreman_bolt: combineReducers({
    emptyState: EmptyStateReducer,
  }),
};

export default reducers;
