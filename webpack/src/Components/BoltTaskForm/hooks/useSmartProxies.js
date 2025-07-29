import { useState, useEffect } from 'react';
import { translate as __ } from 'foremanReact/common/I18n';
import { API } from 'foremanReact/redux/API';
import { useShowMessage } from '../../common/helpers';

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
          search: 'feature=Bolt'
        })}`;
        const { data, status } = await API.get(endpoint);
        
        if (status !== 200) {
          const error = data ? data.error || JSON.stringify(data) : 'Unknown error';
          throw new Error(`HTTP ${status} - ${error}`);
        }
        
        setSmartProxies(data.results || []);
        
        if (data.results.length === 0) {
          showMessage(__('No Smart Proxies found. Please check that one or more proxy has the smart_proxy_bolt package installed and enabled.'));
        }
      } catch (error) {
        showMessage(__('Failed to load Smart Proxies: ') + error.message);
      } finally {
        setIsLoadingProxies(false);
      }
    };

    fetchSmartProxies();
  }, [showMessage]);

  return { smartProxies, isLoadingProxies };
};
