import { useState, useCallback } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { ROUTES } from '../../common/constants';
import { useShowMessage } from '../../common/helpers';

export const useBoltOptions = () => {
  const showMessage = useShowMessage();

  const [boltOptionsMetadata, setBoltOptionsMetadata] = useState({});
  const [boltOptions, setBoltOptions] = useState({});
  const [isLoadingOptions, setIsLoadingOptions] = useState(false);

  const fetchBoltOptions = useCallback(
    async proxyId => {
      if (!proxyId) return null;

      setIsLoadingOptions(true);
      setBoltOptionsMetadata({});
      setBoltOptions({});

      try {
        const { data, status } = await API.get(
          `${ROUTES.API.FETCH_BOLT_OPTIONS}?proxy_id=${proxyId}`
        );

        if (status !== 200) {
          const error = data
            ? data.error || JSON.stringify(data)
            : 'Unknown error';
          throw new Error(`HTTP ${status} - ${error}`);
        }

        setBoltOptionsMetadata(data || {});

        // Set defaults
        const defaults = {};
        Object.entries(data || {}).forEach(([optionName, optionMeta]) => {
          if (optionMeta.default !== undefined) {
            defaults[optionName] = optionMeta.default;
          }
        });
        setBoltOptions(defaults);

        return data;
      } catch (error) {
        showMessage(__('Failed to load Bolt options: ') + error.message);
        return null;
      } finally {
        setIsLoadingOptions(false);
      }
    },
    [showMessage]
  );

  return {
    boltOptionsMetadata,
    boltOptions,
    setBoltOptions,
    isLoadingOptions,
    fetchBoltOptions,
  };
};
