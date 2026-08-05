import {
  initFaviconSwitcher,
  showBadgeOnFavicon,
} from '../AudioAlerts/faviconHelper';

describe('faviconHelper', () => {
  beforeEach(() => {
    document.head.innerHTML = `
      <link class="favicon" data-default-href="/brand-assets/alvorada-icon-16x16.png?v=20260804" data-badge-href="/brand-assets/alvorada-icon-badge-16x16.png?v=20260804" href="/brand-assets/alvorada-icon-16x16.png?v=20260804" />
    `;
  });

  it('uses the branded badge asset for unread notifications', () => {
    showBadgeOnFavicon();

    expect(document.querySelector('.favicon').href).toContain(
      '/brand-assets/alvorada-icon-badge-16x16.png?v=20260804'
    );
  });

  it('restores the branded favicon when the dashboard becomes visible', () => {
    initFaviconSwitcher();
    showBadgeOnFavicon();
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'visible',
    });
    document.dispatchEvent(new Event('visibilitychange'));

    expect(document.querySelector('.favicon').href).toContain(
      '/brand-assets/alvorada-icon-16x16.png?v=20260804'
    );
  });
});
