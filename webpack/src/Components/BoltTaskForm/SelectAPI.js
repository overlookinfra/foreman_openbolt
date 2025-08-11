import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import URI from 'urijs';
import { SelectVariant } from '@patternfly/react-core/deprecated';
import { get } from 'foremanReact/redux/API';
import { SearchSelect } from './SearchSelect';
import {
  selectAPIResponse,
  selectAPIStatus,
} from 'foremanReact/redux/API/APISelectors';

export const useNameSearchAPI = (apiKey, url) => {
  console.log('Calling useNameSearchAPI with apiKey:', apiKey, 'and url:', url);
  const dispatch = useDispatch();
  const uri = new URI(url);
  const onSearch = search =>
    dispatch(
      get({
        key: apiKey,
        url: uri.addSearch({
          search: `name~"${search}"`,
        }),
      })
    );

  const response = useSelector(state => selectAPIResponse(state, apiKey));
  const isLoading = useSelector(state => selectAPIStatus(state, apiKey) === STATUS.PENDING);
  return [onSearch, response, isLoading];
};

export const SelectAPI = props => (
  <SearchSelect
    {...props}
    variant={SelectVariant.typeaheadMulti}
    useNameSearch={useNameSearchAPI}
  />
);
