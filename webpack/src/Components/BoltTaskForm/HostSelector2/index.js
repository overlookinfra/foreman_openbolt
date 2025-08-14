/* Note: A lot of this code was adapted from foreman_remote_execution,
 * specifically the JobWizard HostsAndInputs step component. Major props
 * to the contributors of that project for their work.
 */
import React, { useState, useEffect, useCallback, useRef } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
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

const HostSelector2 = ({
  onChange,
}) => {
  // Was from JobWizardConstants. Move into ours maybe.
  const hostMethods = {
    hosts: __('Hosts'),
    hostGroups: __('Host groups'),
    searchQuery: __('Search query'),
  };

  const selectOptions = Object.values(hostMethods).map((method, index) => (
      <SelectOption key={index + 1} value={method}>{method}</SelectOption>
    ));
  
  const [hostMethod, setHostMethod] = useState(hostMethods.hosts);
  const [isOpen, setIsOpen] = useState(false);
  const [errorText, setErrorText] = useState('');
  const [isError, setIsError] = useState(false);
  const [hostsSearchQuery, setHostsSearchQuery] = useState('');
  const [selectedTargets, setSelectedTargets] = useState({
    hosts: [],
    hostGroups: [],
  });

  const setLabel = result => result.displayName || result.name;
  const selectedHosts = selectedTargets.hosts;
  const setSelectedHosts = newHostsFn =>
    setSelectedTargets(prev => ({
      ...prev,
      hosts: newHostsFn(prev.hosts),
    }));
  
    const selectedHostGroups = selectedTargets.hostGroups;
    const setSelectedHostGroups = newHostGroupsFn =>
      setSelectedTargets(prev => ({
        ...prev,
        hostGroups: newHostGroupsFn(prev.hostGroups),
    }));
  const clearSearch = () => {
    setHostsSearchQuery('');
  };

  // When nothing is selected, show error text
  useEffect(() => {
      setIsError(
        selectedTargets.hosts.length === 0 &&
        selectedTargets.hostGroups.length === 0 &&
        hostsSearchQuery.trim().length === 0
      );
  }, [hostsSearchQuery, selectedTargets, hostMethod]);

  // When any of these get set, fetch the list of targets and
  // update the parent component.
  useEffect(() => {
    const buildTargetsFromSearch = async () => {
      const searchParts = [];

      // Add direct host names - fix the syntax
      if (selectedTargets.hosts.length > 0) {
        const hostNames = selectedTargets.hosts.map(h => `name = "${h.name}"`).join(' or ');
        searchParts.push(`(${hostNames})`);
      }

      // Add host groups - fix the syntax  
      if (selectedTargets.hostGroups.length > 0) {
        const groupQueries = selectedTargets.hostGroups.map(g => `hostgroup_fullname = "${g.name}"`).join(' or ');
        searchParts.push(`(${groupQueries})`);
      }

      // Add custom search query
      if (hostsSearchQuery.trim().length > 0) {
        searchParts.push(`(${hostsSearchQuery.trim()})`);
      }

      if (searchParts.length === 0) {
        onChange('');
        return;
      }

      try {
        // Combine all search parts with OR
        const finalSearch = searchParts.join(' or ');
        console.log('Final search query:', finalSearch); // Debug log
        const searchParams = new URLSearchParams({
          search: finalSearch,
          per_page: 1000,
          thin: '1',
        })
        const response = await API.get(`/api/hosts?${searchParams.toString()}`)
        console.log('API request URL:', response.config?.url); // Debug the actual URL
        console.log('Response data:', response.data); // Debug the response
        const hosts = response.data?.results?.map(host => host.name) || [];
        const targetString = hosts.join(',');
        console.log('Target string:', targetString); // Debug the final result
        onChange(targetString);
      } catch (error) {
        console.error('Error building target list:', error);
        onChange('');
      }
    };

    buildTargetsFromSearch();
  }, [selectedTargets, hostsSearchQuery, onChange]);

  const onSelect = (_event, selection) => {
    setHostMethod(selection);
    setIsOpen(false);
    switch (selection) {
      case hostMethods.hosts:
        setErrorText(__('Please select at least one host'));
        break;
      case hostMethods.hostGroups:
        setErrorText(__('Please select at least one host group'));
        break;
      case hostMethods.searchQuery:
        setErrorText(__('Please enter a search query'));
        break;
      default:
        break;
    }
  }

  const onToggleClick = () => setIsOpen(!isOpen);

  const toggle = (toggleRef) => (
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
      <FormGroup
        fieldId="host-selector"
        label={__('Hosts')}
      >
        <InputGroup>
          <InputGroupItem>
            <FormGroup
              fieldId='host_methods'
              isRequired
            >
              <Select
                ouiaId='host_methods'
                selected={hostMethod}
                onSelect={onSelect}
                toggle={toggle}
                isOpen={isOpen}
                className="without_select2"
                aria-labelledby={'host_methods'}
              >
                {selectOptions}
              </Select>
            </FormGroup>
          </InputGroupItem>
          {hostMethod == hostMethods.hosts && (
            <SearchSelect
              selected={selectedTargets.hosts}
              setSelected={setSelectedHosts}
              apiKey={'HOSTS'}
              name="hosts"
              placeholderText={__('Filter by hosts')}
              setLabel={setLabel}
            />
          )}
          {hostMethod == hostMethods.hostGroups && (
            <SearchSelect
              selected={selectedTargets.hostGroups}
              setSelected={setSelectedHostGroups}
              apiKey={'HOST_GROUPS'}
              name="host groups"
              placeholderText={__('Filter by host groups')}
              setLabel={setLabel}
            />
          )}
          {hostMethod === hostMethods.searchQuery && (
            <HostSearch
              setValue={setHostsSearchQuery}
              value={hostsSearchQuery}
            />
          )}
        </InputGroup>
        {isError && (
          <FormHelperText>
            <HelperText>{errorText}</HelperText>
          </FormHelperText>
        )}
      </FormGroup>
      <SelectedChips
        selectedHosts={selectedHosts}
        setSelectedHosts={setSelectedHosts}
        selectedHostGroups={selectedHostGroups}
        setSelectedHostGroups={setSelectedHostGroups}
        hostsSearchQuery={hostsSearchQuery}
        clearSearch={clearSearch}
        setLabel={setLabel}
      />
    </div>
  )
};

export default HostSelector2;
