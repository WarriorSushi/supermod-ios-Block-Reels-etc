(() => {
  'use strict';
  const config = globalThis.supermodBootstrap;
  delete globalThis.supermodBootstrap;
  const hosts = new Set(['facebook.com', 'www.facebook.com', 'm.facebook.com']);
  const owns = url => url.protocol === 'https:' && !url.port && !url.username && !url.password && hosts.has(url.hostname);
  if (!config || !owns(location)) return;

  let hidden = new Set(config.hidden);
  let marked = new Set();
  let resizedTabs = new Set();
  let css;
  let scheduled = false;
  let lastPath = location.pathname;
  let lastChrome;
  let headerRows = [];
  let headerShift = 0;
  let lastFeedOffset = 0;
  let directionAnchor = 0;
  let headerRevealed = false;
  let scrollFrame = 0;
  const part = path => path.split('/').filter(Boolean)[0]?.toLowerCase() ?? '';
  const routeMod = path => {
    const key = part(path);
    return key === 'reel' || key === 'reels' ? 'reels' : key === 'stories' ? 'stories' : null;
  };
  const home = () => ['', 'home.php'].includes(part(location.pathname));
  const showsAppPromo = () => home() || part(location.pathname) === 'search';
  const videoPage = () => /^\/(?:[^/]+\/)?videos(?:\/|$)/i.test(location.pathname);
  const chrome = () => {
    if (routeMod(location.pathname) === 'reels') return 'dark';
    // Facebook can open its swipeable Reels viewer at a profile video URL.
    if (videoPage()) {
      for (const screen of document.querySelectorAll('[data-mcomponent="MScreen"]')) {
        if (!screen.getClientRects().length ||
            !screen.querySelector('[data-type="vscroller"].vscroller-snap')) continue;
        if ([...screen.querySelectorAll('h2')].some(heading => labels.reels.has(normalize(heading.textContent)))) {
          return 'dark';
        }
      }
    }
    const screens = document.querySelectorAll('[data-mcomponent="MScreen"][data-light-status-bar="true"]');
    return [...screens].some(screen => screen.getClientRects().length > 0) ? 'light' : null;
  };
  const parse = link => {
    try {
      const url = new URL(link.getAttribute('href'), location.href);
      return owns(url) ? url : null;
    } catch {
      return null;
    }
  };
  const normalize = value => (value ?? '').replace(/[\u200b-\u200f\u202a-\u202e\u2066-\u2069]/g, '').trim().toLowerCase();
  const labels = {
    reels: new Set(['reels', 'రీల్స్']),
    stories: new Set(['stories', 'స్టోరీలు', 'కథనాలు']),
    sponsored: new Set(['sponsored', 'ad', 'ప్రాయోజితం', 'ప్రకటన'])
  };
  const card = '[data-pagelet^="FeedUnit_"], article, [role="article"]';
  const landmark = 'nav, [role="navigation"], header, [role="banner"], [role="tablist"]';
  const protectedArea = '[role="dialog"], [role="textbox"], [contenteditable="true"], form';
  const linkMod = link => routeMod(parse(link)?.pathname ?? '');
  const report = message => globalThis.webkit?.messageHandlers?.supermod?.postMessage(message);
  const mobileScroller = '[data-mcomponent="MContainer"][data-type="vscroller"]';
  const mobileTabs = '[role="tablist"][data-mcomponent="MContainer"]';
  const tabLabel = tab => normalize(tab.getAttribute('aria-label')).split(/[,:(]/, 1)[0].trim();
  const tabLayoutCSS = `
    [role="tablist"][data-mcomponent="MContainer"] > [role="tab"][data-supermod-tab] {
      width: var(--supermod-tab-width) !important;
      margin-left: var(--supermod-tab-left) !important;
      align-items: center !important;
    }
    [data-supermod-revealed-header] {
      transform: translateY(var(--supermod-header-shift)) !important;
      z-index: 30 !important;
      background-color: var(--supermod-header-fill) !important;
    }
  `;

  function mobileFeed() {
    const tabs = document.querySelector(mobileTabs);
    const feed = tabs?.closest(mobileScroller);
    return feed?.querySelector('[aria-label="Post a status update" i]') ? feed : null;
  }

  function mobileRow(node, feed) {
    let row = node;
    while (row.parentElement && row.parentElement !== feed) row = row.parentElement;
    return row.parentElement === feed ? row : null;
  }

  function moveHeader(shift) {
    if (shift === headerShift) return;
    const wasRevealed = headerShift > 0;
    headerShift = shift;
    for (const row of headerRows) {
      row.toggleAttribute('data-supermod-revealed-header', shift > 0);
      if (shift > 0) {
        row.style.setProperty('--supermod-header-shift', shift + 'px');
        if (!wasRevealed) row.style.setProperty('--supermod-header-fill', chrome() === 'light' ? 'white' : '#242526');
      } else {
        row.style.removeProperty('--supermod-header-shift');
        row.style.removeProperty('--supermod-header-fill');
      }
    }
  }

  function trackHeader(feed) {
    const tabs = feed?.querySelector(mobileTabs);
    const previous = tabs?.previousElementSibling;
    const hasTitleRow = previous?.matches('[data-mcomponent="MContainer"]') &&
      previous.querySelectorAll('[role="button"]').length >= 2;
    const rows = tabs ? (hasTitleRow ? [previous, tabs] : [tabs]) : [];
    if (rows.length === headerRows.length && rows.every((row, index) => row === headerRows[index])) return;
    moveHeader(0);
    headerRows = rows;
    lastFeedOffset = directionAnchor = 0;
    headerRevealed = false;
  }

  window.addEventListener('scroll', () => {
    if (!headerRows.length || scrollFrame) return;
    scrollFrame = setTimeout(() => {
      scrollFrame = 0;
      const first = headerRows[0];
      if (!first?.isConnected) return;
      const offset = Math.max(0, headerShift - first.getBoundingClientRect().top);
      if (offset <= 1) {
        headerRevealed = false;
        directionAnchor = 0;
      } else if (headerRevealed) {
        directionAnchor = Math.min(directionAnchor, offset);
        if (offset - directionAnchor >= 8) {
          headerRevealed = false;
          directionAnchor = offset;
        }
      } else {
        directionAnchor = Math.max(directionAnchor, lastFeedOffset, offset);
        if (directionAnchor - offset >= 6) {
          headerRevealed = true;
          directionAnchor = offset;
        }
      }
      lastFeedOffset = offset;
      moveHeader(headerRevealed ? offset : 0);
    }, 16);
  }, { capture: true, passive: true });

  function markMobileFeed(feed, next) {
    if (hidden.has('reels')) {
      for (const tab of feed.querySelectorAll(mobileTabs + ' > [role="tab"]')) {
        if (labels.reels.has(tabLabel(tab))) next.add(tab);
      }
      for (const heading of feed.querySelectorAll('h2[data-mcomponent="TextArea"]')) {
        if (!labels.reels.has(normalize(heading.textContent))) continue;
        const row = mobileRow(heading, feed);
        if (row?.hasAttribute('data-tracking-duration-id')) next.add(row);
      }
    }
    if (hidden.has('stories')) {
      for (const button of feed.querySelectorAll('[role="button"][aria-label="Create story" i]')) {
        const row = mobileRow(button, feed);
        if (row?.matches('[data-mcomponent="MContainer"][data-type="container"]') &&
            !row.querySelector(mobileTabs + ', [aria-label="Post a status update" i]')) next.add(row);
      }
    }
    if (hidden.has('sponsored')) {
      for (const row of feed.querySelectorAll(':scope > [data-tracking-duration-id]')) {
        if (!row.closest(protectedArea) && isSponsored(row)) next.add(row);
      }
    }
  }

  function resizeMobileTabs(feed, next) {
    const resized = new Set();
    for (const bar of feed?.querySelectorAll(mobileTabs) ?? []) {
      const tabs = [...bar.children];
      if (!tabs.every(tab => tab.matches('[role="tab"]'))) continue;
      const visible = tabs.filter(tab => !next.has(tab));
      if (!visible.length || visible.length === tabs.length || next.has(tabs[0])) continue;

      // Facebook positions these tabs with stacked rows and inline margins.
      // Resize horizontally while preserving the site's vertical positioning.
      const width = 100 / visible.length;
      visible.forEach((tab, index) => {
        tab.setAttribute('data-supermod-tab', '');
        tab.style.setProperty('--supermod-tab-width', width + '%');
        tab.style.setProperty('--supermod-tab-left', (index * width) + '%');
        resized.add(tab);
      });
    }
    for (const tab of resizedTabs) {
      if (resized.has(tab)) continue;
      tab.removeAttribute('data-supermod-tab');
      tab.style.removeProperty('--supermod-tab-width');
      tab.style.removeProperty('--supermod-tab-left');
    }
    resizedTabs = resized;
  }

  function isSponsored(unit) {
    if ([...unit.querySelectorAll('a[href]')].some(link => {
      const path = parse(link)?.pathname.replace(/\/$/, '');
      return !link.closest('blockquote, [role="dialog"]') && path === '/ads/about';
    })) return true;

    // A short label is evidence only in post metadata, never in its caption or author link.
    return [...unit.querySelectorAll('header, [role="heading"]')].some(header =>
      !header.closest('blockquote, [role="dialog"]') &&
      [...header.querySelectorAll('span, [aria-label]')].some(badge =>
        !badge.closest('a, [role="link"], button, [role="button"]') &&
        (labels.sponsored.has(normalize(badge.getAttribute('aria-label'))) ||
          (!badge.children.length && labels.sponsored.has(normalize(badge.textContent))))));
  }

  function scan() {
    scheduled = false;
    const root = document.documentElement;
    if (!root) return;
    const blocked = hidden.has(routeMod(location.pathname));
    const hasPasswordField = !!document.querySelector('input[type="password"]');
    const signedInHome = home() && !hasPasswordField;
    const filteringFeed = signedInHome && hidden.size > 0;
    const mobile = signedInHome ? mobileFeed() : null;
    if (blocked || filteringFeed || mobile) {
      if (!css?.isConnected) {
        css = document.createElement('style');
        css.textContent = config.css + tabLayoutCSS;
        (document.head ?? root).append(css);
      }
    }
    root.toggleAttribute('data-supermod-blocked', blocked);
    root.toggleAttribute('data-supermod-active', filteringFeed);
    const next = new Set();
    if (filteringFeed) {
      if (mobile) markMobileFeed(mobile, next);
      for (const link of document.querySelectorAll(':is(' + landmark + ') a[href]')) {
        if (link.closest(protectedArea) || link.closest(card)) continue;
        if (!hidden.has(linkMod(link))) continue;
        // Collapse a dedicated tab's layout slot, keeping neighboring tabs intact.
        const slot = link.closest('li, [role="tab"]');
        next.add(slot && slot.querySelectorAll('a[href], button').length === 1 ? slot : link);
      }
      for (const rail of document.querySelectorAll('section[aria-label], [role="region"][aria-label], [data-pagelet="Stories"], [data-pagelet="Reels"]')) {
        if (rail.closest(protectedArea)) continue;
        const name = normalize(rail.getAttribute('aria-label') || rail.getAttribute('data-pagelet'));
        for (const mod of ['stories', 'reels']) {
          if (hidden.has(mod) && labels[mod].has(name) &&
              [...rail.querySelectorAll('a[href]')].some(link => linkMod(link) === mod)) next.add(rail);
        }
      }
      if (hidden.has('sponsored')) {
        for (const unit of document.querySelectorAll(':is(main, [role="main"], [role="feed"]) :is(' + card + ')')) {
          if (unit.closest(protectedArea) || unit.parentElement?.closest(card) || !isSponsored(unit)) continue;
          next.add(unit);
        }
      }
    }
    for (const node of marked) if (!next.has(node)) node.classList.remove('supermod-hidden');
    for (const node of next) if (!marked.has(node)) node.classList.add('supermod-hidden');
    marked = next;
    resizeMobileTabs(mobile, next);
    trackHeader(mobile);
    const currentChrome = chrome();
    if (currentChrome !== lastChrome) {
      lastChrome = currentChrome;
      report('page-state');
    }
  }

  function queueScan() {
    if (scheduled) return;
    scheduled = true;
    setTimeout(scan, 35);
  }
  function onRoute() {
    if (lastPath === location.pathname) return;
    lastPath = location.pathname;
    scan();
    report('route');
  }
  for (const event of ['supermod:route', 'popstate', 'hashchange']) window.addEventListener(event, onRoute);
  window.addEventListener('click', event => {
    if (!event.isTrusted || !home() || !globalThis.webkit?.messageHandlers?.supermod) return;
    const tab = event.target.closest?.(mobileTabs + ' > [role="tab"]');
    if (!tab || !/^(?:messenger|messages)\b/.test(tabLabel(tab))) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    report('facebook-messenger');
  }, true);
  new MutationObserver(() => { if (showsAppPromo() || videoPage()) queueScan(); }).observe(document, {
    childList: true, subtree: true, characterData: true, attributes: true,
    attributeFilter: ['aria-label', 'href', 'data-pagelet', 'role', 'type']
  });
  globalThis.supermodApply = value => {
    hidden = new Set(value);
    scan();
    return true;
  };
  globalThis.supermodPageState = () => {
    if (document.querySelector('input[type="password"]')) return 'login';
    if (!home()) return 'connected';
    return mobileFeed() || document.querySelector('[role="feed"], [data-pagelet^="FeedUnit_"]') ? 'feed' : 'uncertain';
  };
  globalThis.supermodChrome = chrome;
  scan();
})();
