import React, { useState, useEffect, useCallback, useRef } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import {
  FormGroup,
  TextInput,
  Chip,
  ChipGroup,
  Menu,
  MenuContent,
  MenuItem,
  MenuList,
  MenuGroup,
  Spinner,
  HelperText,
  HelperTextItem,
  Divider
} from '@patternfly/react-core';
import { SearchIcon } from '@patternfly/react-icons';
import './styles.scss';

const HostSelector = ({ 
  value, 
  onChange, 
  required = false,
  placeholder = __('Search for hosts...'),
  helperText = __('Search and select hosts or host groups. You can also enter host names directly.')
}) => {
  const containerRef = useRef();
  const searchInputRef = useRef();
  
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState({ hosts: [], hostGroups: [] });
  const [selectedItems, setSelectedItems] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [recentHosts, setRecentHosts] = useState([]);
  
  // Initialize selected items from value prop
  useEffect(() => {
    if (value && typeof value === 'string') {
      const items = value.split(',').map(item => item.trim()).filter(Boolean);
      const parsedItems = items.map(item => {
        if (item.includes('hostgroup=')) {
          const match = item.match(/hostgroup="([^"]+)"/);
          if (match) {
            return {
              type: 'hostgroup',
              value: item,
              display: `Group: ${match[1]}`,
              name: match[1]
            };
          }
        }
        return {
          type: 'host',
          value: item,
          display: item,
          name: item
        };
      });
      setSelectedItems(parsedItems);
    }
  }, []);

  // Load recent hosts from localStorage
  useEffect(() => {
    try {
      const stored = localStorage.getItem('foreman_bolt_recent_hosts');
      if (stored) {
        const parsed = JSON.parse(stored);
        setRecentHosts(parsed.slice(0, 5));
      }
    } catch (error) {
      // Silent fail
    }
  }, []);

  // Save selected hosts to recent
  const saveToRecent = useCallback((hostName) => {
    try {
      const stored = localStorage.getItem('foreman_bolt_recent_hosts');
      let recent = stored ? JSON.parse(stored) : [];
      recent = [hostName, ...recent.filter(h => h !== hostName)].slice(0, 10);
      localStorage.setItem('foreman_bolt_recent_hosts', JSON.stringify(recent));
    } catch (error) {
      // Silent fail
    }
  }, []);

  // Search for hosts and host groups
  const searchForHosts = useCallback(async (query) => {
    if (!query || query.length < 2) {
      setSearchResults({ hosts: [], hostGroups: [] });
      return;
    }

    setIsSearching(true);
    try {
      const [hostsResponse, hostGroupsResponse] = await Promise.all([
        API.get('/api/hosts', {
          params: {
            search: `name~${query}`,
            per_page: 10,
            thin: 1
          }
        }),
        API.get('/api/hostgroups', {
          params: {
            search: `name~${query}`,
            per_page: 5
          }
        })
      ]);

      const hosts = hostsResponse.data?.results || [];
      const hostGroups = hostGroupsResponse.data?.results || [];
      const hostGroupsWithCounts = await Promise.all(
        hostGroups.map(async group => {
          const response = await API.get(`/api/hostgroups/${group.id}/hosts`, { params: { thin: 1 } });
          const hostsInGroup = response.data?.results || [];
          console.log(hostsInGroup.length);
          return {
            ...group,
            hosts_count: hostsInGroup.length,
          };
        })
      );

      setSearchResults({ hosts: hosts, hostGroups: hostGroupsWithCounts });
    } catch (error) {
      console.error('Search error:', error);
      setSearchResults({ hosts: [], hostGroups: [] });
    } finally {
      setIsSearching(false);
    }
  }, []);

  const debounce = (func, wait) => {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  };

  // Debounced search
  const debouncedSearch = useCallback(
    debounce((query) => searchForHosts(query), 300),
    [searchForHosts]
  );

  // Handle search input change
  const handleSearchChange = (value) => {
    setSearchQuery(value);
    if (value.length >= 2) {
      setIsMenuOpen(true);
      debouncedSearch(value);
    } else if (value.length === 0 && recentHosts.length > 0) {
      setIsMenuOpen(true);
      setSearchResults({ hosts: [], hostGroups: [] });
    } else {
      setIsMenuOpen(false);
    }
  };

  // Add an item (host or host group)
  const handleAddItem = (item) => {
    const newItem = {
      type: item.type,
      value: item.type === 'hostgroup' 
        ? `hostgroup="${item.name}"` 
        : item.name,
      display: item.type === 'hostgroup' 
        ? `Group: ${item.title || item.name}`
        : item.name,
      name: item.name
    };

    const exists = selectedItems.some(selected => 
      selected.type === newItem.type && selected.name === newItem.name
    );

    if (!exists) {
      const newItems = [...selectedItems, newItem];
      setSelectedItems(newItems);
      updateFormValue(newItems);
      
      if (item.type === 'host') {
        saveToRecent(item.name);
      }
    }

    setSearchQuery('');
    setIsMenuOpen(false);
    searchInputRef.current?.focus();
  };

  // Remove an item
  const handleRemoveItem = (itemToRemove) => {
    const newItems = selectedItems.filter(item => 
      !(item.type === itemToRemove.type && item.name === itemToRemove.name)
    );
    setSelectedItems(newItems);
    updateFormValue(newItems);
  };

  // Update the form value
  const updateFormValue = (items) => {
    const value = items.map(item => item.value).join(',');
    onChange(value);
  };

  // Handle Enter key to add direct input
  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && searchQuery.trim()) {
      e.preventDefault();
      if (!isMenuOpen || (searchResults.hosts.length === 0 && searchResults.hostGroups.length === 0)) {
        handleAddItem({
          type: 'host',
          name: searchQuery.trim()
        });
      }
    } else if (e.key === 'Escape') {
      setIsMenuOpen(false);
    }
  };

  // Handle clicking outside to close menu
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsMenuOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Build menu content
  const menuContent = (
    <div 
      style={{
        position: 'absolute',
        top: '100%',
        left: 0,
        right: 0,
        zIndex: 1000,
        marginTop: '4px',
        backgroundColor: 'var(--pf-v5-global--BackgroundColor--100, #fff)',
        border: '1px solid var(--pf-v5-global--BorderColor--100, #d2d2d2)',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
        borderRadius: '3px',
        maxHeight: '300px',
        overflowY: 'auto'
      }}
    >
      <Menu>
        <MenuContent>
          <MenuList>
            {isSearching && (
              <MenuItem isDisabled>
                <Spinner size="sm" /> {__('Searching...')}
              </MenuItem>
            )}
            
            {!isSearching && searchQuery.length < 2 && recentHosts.length > 0 && (
              <MenuGroup label={__('Recent hosts')}>
                {recentHosts.map(host => (
                  <MenuItem
                    key={`recent-${host}`}
                    onClick={() => handleAddItem({ type: 'host', name: host })}
                  >
                    {host}
                  </MenuItem>
                ))}
              </MenuGroup>
            )}
            
            {!isSearching && searchResults.hosts.length > 0 && (
              <MenuGroup label={__('Hosts')}>
                {searchResults.hosts.map(host => (
                  <MenuItem
                    key={`host-${host.id}`}
                    onClick={() => handleAddItem({ ...host, type: 'host' })}
                    description={host.operatingsystem_name}
                  >
                    {host.name}
                  </MenuItem>
                ))}
              </MenuGroup>
            )}
            
            {!isSearching && searchResults.hosts.length > 0 && searchResults.hostGroups.length > 0 && (
              <Divider component="li" />
            )}
            
            {!isSearching && searchResults.hostGroups.length > 0 && (
              <MenuGroup label={__('Host Groups')}>
                {searchResults.hostGroups.map(group => (
                  <MenuItem
                    key={`group-${group.id}`}
                    onClick={() => handleAddItem({ ...group, type: 'hostgroup' })}
                    description={`${group.hosts_count || 0} hosts`}
                  >
                    {group.title || group.name}
                  </MenuItem>
                ))}
              </MenuGroup>
            )}
            
            {!isSearching && searchQuery.length >= 2 && 
             searchResults.hosts.length === 0 && searchResults.hostGroups.length === 0 && (
              <MenuItem isDisabled>
                {__('No results found. Press Enter to add as host name.')}
              </MenuItem>
            )}
          </MenuList>
        </MenuContent>
      </Menu>
    </div>
  );

  return (
    <FormGroup
      label={__('Target Hosts')}
      fieldId="hosts-selector"
      isRequired={required}
    >
      <div ref={containerRef} style={{ position: 'relative' }}>
        {selectedItems.length > 0 && (
        <ChipGroup categoryName={__('Selected')} className="pf-v5-u-mt-sm">
          {selectedItems.map((item, index) => (
            <Chip 
              key={`${item.type}-${item.name}-${index}`}
              onClick={() => handleRemoveItem(item)}
            >
              {item.display}
            </Chip>
          ))}
        </ChipGroup>
      )}
        <TextInput
          ref={searchInputRef}
          id="hosts-search"
          type="search"
          placeholder={placeholder}
          value={searchQuery}
          onChange={(_, value) => handleSearchChange(value)}
          onKeyDown={handleKeyDown}
          onFocus={() => {
            if (searchQuery.length >= 2 || (searchQuery.length === 0 && recentHosts.length > 0)) {
              setIsMenuOpen(true);
            }
          }}
          aria-label={__('Search for hosts')}
          customIcon={<SearchIcon />}
          required={required && selectedItems.length === 0}
        />
        
        {isMenuOpen && menuContent}
      </div>

      <HelperText>
        <HelperTextItem>{helperText}</HelperTextItem>
      </HelperText>
    </FormGroup>
  );
};

export default HostSelector;
