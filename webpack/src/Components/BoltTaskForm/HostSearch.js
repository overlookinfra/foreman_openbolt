import React from 'react';
import PropTypes from 'prop-types';
import SearchBar from 'foremanReact/components/SearchBar';
import { getControllerSearchProps } from 'foremanReact/constants';

export const HostSearch = ({ value, setValue }) => {
  console.log('Rendering HostSearch with value:', value);
  const props = getControllerSearchProps('hosts', 'mainHostQuery');
  return (
    <div className="foreman-search-field">
      <SearchBar
        data={{
          ...props,
          autocomplete: {
            id: 'mainHostQuery',
            url: '/foreman_bolt/auto_complete_search',
            searchQuery: value,
          },
        }}
        onSearch={null}
        onSearchChange={search => setValue(search)}
      />
    </div>
  );
};

HostSearch.propTypes = {
  value: PropTypes.string.isRequired,
  setValue: PropTypes.func.isRequired,
};
