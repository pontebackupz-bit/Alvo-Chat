const updateFavicons = attribute => {
  document.querySelectorAll('.favicon').forEach(favicon => {
    const href = favicon.dataset[attribute];
    if (href) favicon.href = href;
  });
};

export const showBadgeOnFavicon = () => updateFavicons('badgeHref');

export const initFaviconSwitcher = () => {
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      updateFavicons('defaultHref');
    }
  });
};
