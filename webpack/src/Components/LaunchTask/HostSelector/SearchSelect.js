import React, { useState, useEffect, useRef } from 'react';
import PropTypes from 'prop-types';
import { useQuery } from '@apollo/client';
import {
  Select,
  SelectOption,
  SelectList,
  MenuToggle,
  TextInputGroup,
  TextInputGroupMain,
  Button,
  Spinner,
  TextInputGroupUtilities,
} from '@patternfly/react-core';
import {
  useForemanOrganization,
  useForemanLocation,
} from 'foremanReact/Root/Context/ForemanContext';
import { decodeId } from 'foremanReact/common/globalIdHelpers';
import { TimesIcon } from '@patternfly/react-icons';
import Immutable from 'seamless-immutable';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import hostsQuery from './hosts.gql';
import hostgroupsQuery from './hostgroups.gql';

export const maxResults = 100;

const queries = {
  HOSTS: hostsQuery,
  HOST_GROUPS: hostgroupsQuery,
};

const dataName = {
  HOSTS: 'hosts',
  HOST_GROUPS: 'hostgroups',
};

const useNameSearch = queryKey => {
  const org = useForemanOrganization();
  const location = useForemanLocation();
  const [search, setSearch] = useState('');

  const { loading, data, error } = useQuery(queries[queryKey], {
    variables: {
      search: [
        `name~"${search}"`,
        org ? `organization_id=${org.id}` : null,
        location ? `location_id=${location.id}` : null,
      ]
        .filter(i => i)
        .join(' and '),
    },
  });
  return [
    setSearch,
    {
      subtotal: data?.[dataName[queryKey]]?.totalCount,
      results:
        data?.[dataName[queryKey]]?.nodes.map(node => ({
          id: decodeId(node.id),
          name: node.name,
          displayName: node.displayName,
        })) || [],
      error: error?.message || null,
    },
    loading,
  ];
};

export const SearchSelect = ({
  name,
  selected,
  setSelected,
  placeholderText,
  apiKey,
  setLabel,
}) => {
  const [onSearch, response, isLoading] = useNameSearch(apiKey);
  const [inputValue, setInputValue] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const typingTimeoutRef = useRef(null);

  useEffect(() => {
    onSearch('');
    return () => {
      if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  let selectOptions = [];

  if (response.error) {
    selectOptions = [
      <SelectOption isDisabled key="error">
        {sprintf(__('Error loading results: %s'), response.error)}
      </SelectOption>,
    ];
  } else if (response.subtotal > maxResults) {
    selectOptions = [
      <SelectOption
        isDisabled
        key={0}
        description={__('Please refine your search.')}
      >
        {sprintf(
          __('You have %s results to display. Showing first %s results'),
          response.subtotal,
          maxResults
        )}
      </SelectOption>,
    ];
  }

  selectOptions = [
    ...selectOptions,
    ...Immutable.asMutable(response?.results || [])?.map((result, index) => (
      <SelectOption key={result.id || index} value={result.id}>
        {setLabel(result)}
      </SelectOption>
    )),
  ];

  const onSelect = (event, selection) => {
    if (selected.map(({ id }) => id).includes(selection)) {
      setSelected(currentSelected =>
        currentSelected.filter(({ id }) => id !== selection)
      );
    } else {
      setSelected(currentSelected => [
        ...currentSelected,
        response.results.find(r => r.id === selection),
      ]);
    }
    setInputValue('');
  };

  const autoSearch = searchTerm => {
    if (typingTimeoutRef.current) clearTimeout(typingTimeoutRef.current);
    typingTimeoutRef.current = setTimeout(() => onSearch(searchTerm), 500);
  };

  const toggle = toggleRef => (
    <MenuToggle
      ref={toggleRef}
      variant="typeahead"
      aria-label={`${name} toggle`}
      onClick={() => setIsOpen(!isOpen)}
      isExpanded={isOpen}
      isFullWidth
    >
      <TextInputGroup isPlain>
        <TextInputGroupMain
          value={inputValue}
          onClick={() => setIsOpen(!isOpen)}
          onChange={(_event, value) => {
            setInputValue(value);
            autoSearch(value || '');
          }}
          aria-label={`${name} typeahead input`}
          role="combobox"
          isExpanded={isOpen}
          aria-controls={`${name}-listbox`}
          placeholder={placeholderText}
        />
        <TextInputGroupUtilities>
          {isLoading && (
            <Spinner size="md" aria-label={__('Loading results')} />
          )}
          {selected.length > 0 && (
            <Button
              variant="plain"
              aria-label={__('Clear selections')}
              onClick={() => {
                setSelected(() => []);
                setInputValue('');
              }}
            >
              <TimesIcon />
            </Button>
          )}
        </TextInputGroupUtilities>
      </TextInputGroup>
    </MenuToggle>
  );

  return (
    <Select
      id={name}
      isOpen={isOpen}
      selected={selected.map(({ id }) => id)}
      onSelect={onSelect}
      onOpenChange={setIsOpen}
      role="listbox"
      toggle={toggle}
    >
      <SelectList
        id={`${name}-listbox`}
        style={{ maxHeight: '45vh', overflowY: 'auto' }}
      >
        {selectOptions}
      </SelectList>
    </Select>
  );
};

SearchSelect.propTypes = {
  name: PropTypes.string,
  selected: PropTypes.array,
  setSelected: PropTypes.func.isRequired,
  setLabel: PropTypes.func.isRequired,
  placeholderText: PropTypes.string,
  apiKey: PropTypes.string.isRequired,
};

SearchSelect.defaultProps = {
  name: 'typeahead select',
  selected: [],
  placeholderText: '',
};
