import React, { useState, useEffect } from 'react';
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

export const SearchSelect = ({
  name,
  selected,
  setSelected,
  placeholderText,
  apiKey,
  url,
  setLabel,
}) => {
  const useNameSearch = apiKey => {
    const org = useForemanOrganization();
    const location = useForemanLocation();
    const [search, setSearch] = useState('');
    const queries = {
      'HOSTS': hostsQuery,
      'HOST_GROUPS': hostgroupsQuery,
    };
    // Was from JobWizardConstants. Move into ours maybe.
    const dataName = {
      'HOSTS': 'hosts',
      'HOST_GROUPS': 'hostgroups',
    };

    const { loading, data } = useQuery(queries[apiKey], {
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
        subtotal: data?.[dataName[apiKey]]?.totalCount,
        results:
          data?.[dataName[apiKey]]?.nodes.map(node => ({
            id: decodeId(node.id),
            name: node.name,
            displayName: node.displayName,
          })) || [],
      },
      loading,
    ];
  };
  
  const [onSearch, response, isLoading] = useNameSearch(apiKey, url);
  const [inputValue, setInputValue] = useState('');
  const [isOpen, setIsOpen] = useState(false);
  const [typingTimeout, setTypingTimeout] = useState(null);
  useEffect(() => {
    onSearch(selected.name || '');
    if (typingTimeout) {
      return () => clearTimeout(typingTimeout);
    }
    return undefined;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  let selectOptions = [];
  if (response.subtotal > maxResults) {
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
      <SelectOption key={index + 1} value={result.id}>
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
    if (typingTimeout) clearTimeout(typingTimeout);
    setTypingTimeout(setTimeout(() => onSearch(searchTerm), 1500));
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
          aria-controls="select-typeahead-listbox"
          placeholder={placeholderText}
        />
        <TextInputGroupUtilities>
          {isLoading && <Spinner size="md" />}
          {selected.length > 0 && (
            <Button
              variant="plain"
              aria-label={__('Clear selections')}
              onClick={() => {
                setSelected([]);
                setInputValue('');
                }
              }
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
      role="menu"
      toggle={toggle}
    >
      <SelectList
        id="select-typeahead-listbox"
        style={{ maxHeight: "45vh", overflowY: "auto" }}
      >
        {selectOptions}
      </SelectList>
    </Select>
  );
};

SearchSelect.propTypes = {
  name: PropTypes.string,
  selected: PropTypes.oneOfType([PropTypes.object, PropTypes.array]),
  setSelected: PropTypes.func.isRequired,
  setLabel: PropTypes.func.isRequired,
  placeholderText: PropTypes.string,
  apiKey: PropTypes.string.isRequired,
  url: PropTypes.string,
  variant: PropTypes.string,
};

SearchSelect.defaultProps = {
  name: 'typeahead select',
  selected: {},
  placeholderText: '',
  url: '',
};
