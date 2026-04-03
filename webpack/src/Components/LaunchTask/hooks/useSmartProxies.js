import { useState, useEffect } from 'react';
import { sprintf, translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { useShowMessage, extractErrorMessage } from '../../common/helpers';

export const useSmartProxies = () => {
  const showMessage = useShowMessage();
  const [smartProxies, setSmartProxies] = useState([]);
  const [isLoadingProxies, setIsLoadingProxies] = useState(false);

  useEffect(() => {
    const fetchSmartProxies = async () => {
      setIsLoadingProxies(true);
      try {
        const endpoint = `/api/smart_proxies?${new URLSearchParams({
          per_page: 'all',
          search: 'feature=OpenBolt',
        })}`;
        const { data } = await API.get(endpoint);

        const results = data.results || [];
        setSmartProxies(results);

        if (results.length === 0) {
          showMessage(
            __(
              'No Smart Proxies found. Please check that one or more proxy has the smart_proxy_openbolt package installed and enabled.'
            )
          );
        }
      } catch (error) {
        showMessage(
          sprintf(
            __('Failed to load Smart Proxies: %s'),
            extractErrorMessage(error)
          )
        );
      } finally {
        setIsLoadingProxies(false);
      }
    };

    fetchSmartProxies();
  }, [showMessage]);

  return { smartProxies, isLoadingProxies };
};
