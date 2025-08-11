import React from 'react';
import PropTypes from 'prop-types';
import { useSelector } from 'react-redux';
import URI from 'urijs';
import { List, ListItem, Modal, Button } from '@patternfly/react-core';
import { translate as __, sprintf } from 'foremanReact/common/I18n';
import {
  useForemanHostsPageUrl,
  useForemanHostDetailsPageUrl,
} from 'foremanReact/Root/Context/ForemanContext';
import {
  selectAPIResponse,
  selectAPIStatus,
  selectAPIErrorMessage,
} from 'foremanReact/redux/API/APISelectors';


export const HostPreviewModal = ({ isOpen, setIsOpen, searchQuery }) => {
  const selectHostsResponse = state => selectAPIResponse(state, 'HOSTS_API');
  const selectHostCount = state =>
  selectHostsResponse(state).subtotal || 0;
  const selectHosts = state => {
  const hosts = selectHostsResponse(state).results || [];
    return hosts.map(host => ({
      name: host.name,
      display_name: host.display_name,
    }));
  };
  const hosts = useSelector(selectHosts);
  const hostsCount = useSelector(selectHostCount);
  const hostsUrl = new URI(useForemanHostsPageUrl());
  const hostUrl = useForemanHostDetailsPageUrl();
  return (
    <Modal
      ouiaId="host-preview-modal"
      title={__('Preview Hosts')}
      isOpen={isOpen}
      onClose={() => setIsOpen(false)}
      appendTo={() => document.getElementsByClassName('bolt-task-form')[0]}
    >
      <List isPlain>
        {hosts.map(host => (
          <ListItem key={host.name}>
            <Button
              ouiaId={`host-preview-${host}`}
              component="a"
              href={`${hostUrl}${host.name}`}
              variant="link"
              target="_blank"
              rel="noreferrer"
              isInline
            >
              {host.display_name}
            </Button>
          </ListItem>
        ))}
        {hostsCount > 20 && (
          <ListItem>
            <Button
              ouiaId="host-preview-more"
              component="a"
              href={hostsUrl.addSearch({ search: searchQuery })}
              variant="link"
              target="_blank"
              rel="noreferrer"
              isInline
            >
              {sprintf(
                __('...and %s more'),
                hostsCount - 20
              )}
            </Button>
          </ListItem>
        )}
      </List>
    </Modal>
  );
};

HostPreviewModal.propTypes = {
  isOpen: PropTypes.bool.isRequired,
  setIsOpen: PropTypes.func.isRequired,
  searchQuery: PropTypes.string.isRequired,
};
HostPreviewModal.defaultPropTypes = {
  searchQuery: '',
};
