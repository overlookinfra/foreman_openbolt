import { useState, useCallback } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { ROUTES } from '../../common/constants';
import { useShowMessage } from '../../common/helpers';

export const useOpenBoltOptions = () => {
  const showMessage = useShowMessage();

  const [openBoltOptionsMetadata, setOpenBoltOptionsMetadata] = useState({});
  const [openBoltOptions, setOpenBoltOptions] = useState({});
  const [isLoadingOptions, setIsLoadingOptions] = useState(false);

  const fetchOpenBoltOptions = useCallback(
    async proxyId => {
      if (!proxyId) return null;

      setIsLoadingOptions(true);
      setOpenBoltOptionsMetadata({});
      setOpenBoltOptions({});

      try {
        const { data, status } = await API.get(
          `${ROUTES.API.FETCH_OPENBOLT_OPTIONS}?proxy_id=${proxyId}`
        );

        if (status !== 200) {
          const error = data
            ? data.error || JSON.stringify(data)
            : 'Unknown error';
          throw new Error(`HTTP ${status} - ${error}`);
        }

        setOpenBoltOptionsMetadata(data || {});

        // Set defaults
        const defaults = {};
        Object.entries(data || {}).forEach(([optionName, optionMeta]) => {
          if (optionMeta.default !== undefined) {
            defaults[optionName] = optionMeta.default;
          }
        });
        setOpenBoltOptions(defaults);

        return data;
      } catch (error) {
        showMessage(__('Failed to load OpenBolt options: ') + error.message);
        return null;
      } finally {
        setIsLoadingOptions(false);
      }
    },
    [showMessage]
  );

  return {
    openBoltOptionsMetadata,
    openBoltOptions,
    setOpenBoltOptions,
    isLoadingOptions,
    fetchOpenBoltOptions,
  };
};
