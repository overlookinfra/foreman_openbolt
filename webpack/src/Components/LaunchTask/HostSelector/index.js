/* Note: A lot of this code was adapted from foreman_remote_execution,
 * specifically the JobWizard HostsAndInputs step component. Major props
 * to the contributors of that project for their work.
 */
import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import {
  FormGroup,
  HelperText,
  Select,
  SelectOption,
  InputGroup,
  InputGroupItem,
  MenuToggle,
  FormHelperText,
} from '@patternfly/react-core';
import { FilterIcon } from '@patternfly/react-icons';
import { SearchSelect } from './SearchSelect';
import { SelectedChips } from './SelectedChips';
import { HostSearch } from './HostSearch';

// Was from JobWizardConstants. Move into ours maybe.
const HOST_METHODS = {
  hosts: __('Hosts'),
  hostGroups: __('Host groups'),
  searchQuery: __('Search query'),
};
const ERROR_MESSAGES = {
  hosts: __('Please select at least one host'),
  hostGroups: __('Please select at least one host group'),
  searchQuery: __('Please enter a search query'),
};

const HostSelector = ({ onChange, targetCount = 0 }) => {
  const [hostMethod, setHostMethod] = useState(HOST_METHODS.hosts);
  const [isOpen, setIsOpen] = useState(false);
  const [errorText, setErrorText] = useState('');
  const [hostsSearchQuery, setHostsSearchQuery] = useState('');
  const [selectedTargets, setSelectedTargets] = useState({
    hosts: [],
    hostGroups: [],
  });
  const [isLoading, setIsLoading] = useState(false);
  const [fetchError, setFetchError] = useState('');

  const setLabel = result => result.displayName || result.name;

  const setSelectedHosts = newHostsFn =>
    setSelectedTargets(prev => ({
      ...prev,
      hosts: newHostsFn(prev.hosts),
    }));

  const setSelectedHostGroups = newHostGroupsFn =>
    setSelectedTargets(prev => ({
      ...prev,
      hostGroups: newHostGroupsFn(prev.hostGroups),
    }));

  const clearSearch = () => {
    setHostsSearchQuery('');
  };

  const hasSelection =
    selectedTargets.hosts.length > 0 ||
    selectedTargets.hostGroups.length > 0 ||
    hostsSearchQuery.trim().length > 0;

  // Build and fetch targets when selections change
  useEffect(() => {
    let cancelled = false;

    const fetchTargets = async () => {
      const searchParts = [];

      // Add direct host names
      if (selectedTargets.hosts.length > 0) {
        const hostNames = selectedTargets.hosts
          .map(h => `name = "${h.name.replace(/"/g, '\\"')}"`)
          .join(' or ');
        searchParts.push(`(${hostNames})`);
      }

      // Add host groups
      if (selectedTargets.hostGroups.length > 0) {
        const groupQueries = selectedTargets.hostGroups
          .map(g => `hostgroup_fullname = "${g.name.replace(/"/g, '\\"')}"`)
          .join(' or ');
        searchParts.push(`(${groupQueries})`);
      }

      // Add custom search query
      if (hostsSearchQuery.trim().length > 0) {
        searchParts.push(`(${hostsSearchQuery.trim()})`);
      }

      if (searchParts.length === 0) {
        onChange([]);
        return;
      }

      setIsLoading(true);
      setFetchError('');

      try {
        const finalSearch = searchParts.join(' or ');

        const searchParams = new URLSearchParams({
          search: finalSearch,
          per_page: 1000,
          thin: '1',
        });
        const response = await API.get(`/api/hosts?${searchParams.toString()}`);

        if (!cancelled) {
          const hostNames =
            response.data?.results?.map(host => host.name) || [];
          onChange(hostNames);
        }
      } catch (error) {
        if (!cancelled) {
          setFetchError(error.message || __('Failed to fetch hosts'));
          onChange([]);
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false);
        }
      }
    };

    // Debounce the fetch
    const timeoutId = setTimeout(fetchTargets, 500);

    return () => {
      cancelled = true;
      clearTimeout(timeoutId);
    };
  }, [selectedTargets, hostsSearchQuery, onChange]);

  const onSelect = (_event, selection) => {
    setHostMethod(selection);
    setIsOpen(false);
    setErrorText(ERROR_MESSAGES[selection] || '');
  };

  const onToggleClick = () => setIsOpen(!isOpen);

  const toggle = toggleRef => (
    <MenuToggle
      ref={toggleRef}
      onClick={onToggleClick}
      isExpanded={isOpen}
      icon={<FilterIcon />}
    >
      {hostMethod}
    </MenuToggle>
  );

  return (
    <div className="host-selector">
      <FormGroup fieldId="host-selector" label={__('Hosts')}>
        {targetCount > 0 && (
          <HelperText>
            <HelperText variant="success">
              {sprintf(__('%s hosts selected'), targetCount)}
            </HelperText>
          </HelperText>
        )}

        {isLoading && (
          <HelperText>
            <HelperText>{__('Loading hosts...')}</HelperText>
          </HelperText>
        )}

        <InputGroup>
          <InputGroupItem>
            <FormGroup fieldId="host_methods" isRequired>
              <Select
                ouiaId="host_methods"
                selected={hostMethod}
                onSelect={onSelect}
                toggle={toggle}
                isOpen={isOpen}
                className="without_select2"
                aria-label={__('Host selection method')}
              >
                {Object.values(HOST_METHODS).map((method, index) => (
                  <SelectOption key={index} value={method}>
                    {method}
                  </SelectOption>
                ))}
              </Select>
            </FormGroup>
          </InputGroupItem>

          {hostMethod === HOST_METHODS.hosts && (
            <SearchSelect
              selected={selectedTargets.hosts}
              setSelected={setSelectedHosts}
              apiKey="HOSTS"
              name="hosts"
              placeholderText={__('Filter by hosts')}
              setLabel={setLabel}
            />
          )}

          {hostMethod === HOST_METHODS.hostGroups && (
            <SearchSelect
              selected={selectedTargets.hostGroups}
              setSelected={setSelectedHostGroups}
              apiKey="HOST_GROUPS"
              name="host groups"
              placeholderText={__('Filter by host groups')}
              setLabel={setLabel}
            />
          )}

          {hostMethod === HOST_METHODS.searchQuery && (
            <HostSearch
              setValue={setHostsSearchQuery}
              value={hostsSearchQuery}
            />
          )}
        </InputGroup>

        {!hasSelection && (
          <FormHelperText>
            <HelperText variant="error">{errorText}</HelperText>
          </FormHelperText>
        )}

        {fetchError && (
          <FormHelperText>
            <HelperText variant="error">{fetchError}</HelperText>
          </FormHelperText>
        )}
      </FormGroup>

      <SelectedChips
        selectedHosts={selectedTargets.hosts}
        setSelectedHosts={setSelectedHosts}
        selectedHostGroups={selectedTargets.hostGroups}
        setSelectedHostGroups={setSelectedHostGroups}
        hostsSearchQuery={hostsSearchQuery}
        clearSearch={clearSearch}
        setLabel={setLabel}
      />
    </div>
  );
};

HostSelector.propTypes = {
  onChange: PropTypes.func.isRequired,
  targetCount: PropTypes.number.isRequired,
};

export default HostSelector;
