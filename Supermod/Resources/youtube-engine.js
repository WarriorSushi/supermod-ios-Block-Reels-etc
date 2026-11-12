(() => {
  'use strict';
  const config = globalThis.supermodBootstrap;
  delete globalThis.supermodBootstrap;
  const hosts = new Set(['youtube.com', 'www.youtube.com', 'm.youtube.com']);
  const owns = url => url.protocol === 'https:' && !url.port && !url.username && !url.password && hosts.has(url.hostname);
  if (!config || !owns(location)) return;

  let hidden = new Set(config.hidden);
  let marked = new Set();
  let sheet;
  let pending = false;
  let path = location.pathname;
  const isShort = url => owns(url) && /^\/shorts(?:\/|$)/i.test(url.pathname);
  const tiles = 'ytm-shorts-lockup-view-model, yt-shorts-lockup-view-model, ytd-reel-item-renderer';
  const shelves = 'ytm-reel-shelf-renderer, ytd-reel-shelf-renderer, ytm-shorts-shelf-renderer, ytd-shorts-shelf-renderer';
  const sections = 'grid-shelf-view-model, ytm-rich-shelf-renderer, ytd-rich-shelf-renderer, ytm-rich-section-renderer, ytd-rich-section-renderer, ytm-shelf-renderer';
  const headings = 'ytm-shelf-header-renderer, yt-shelf-header-view-model, yt-section-header-view-model, ytm-rich-shelf-renderer-header';
  const navigation = 'ytm-pivot-bar-item-renderer, yt-tab-shape, ytd-mini-guide-entry-renderer, ytd-guide-entry-renderer';

  function isShortsCard(card) {
    const thumbnail = card.querySelector(':scope > ytm-media-item > a.media-item-thumbnail-container[href]');
    if (!thumbnail) return false;
    try { return isShort(new URL(thumbnail.getAttribute('href'), location.href)); }
    catch { return false; }
  }

  function hasRegularVideos(section) {
    if ([...section.querySelectorAll('ytm-video-with-context-renderer, ytm-video-renderer, ytd-video-renderer')]
      .some(card => !isShortsCard(card))) return true;
    return [...section.querySelectorAll('a[href]')].some(anchor => {
      try {
        const url = new URL(anchor.getAttribute('href'), location.href);
        return owns(url) && /^\/(watch|live|playlist)(?:\/|$)/i.test(url.pathname);
      } catch { return false; }
    });
  }

  function scan() {
    pending = false;
    const root = document.documentElement;
    if (!root) return;
    const enabled = hidden.has('reels');
    if (enabled && !sheet?.isConnected) {
      sheet = document.createElement('style');
      sheet.textContent = config.css;
      (document.head ?? root).append(sheet);
    }
    root.toggleAttribute('data-supermod-active', enabled);
    root.toggleAttribute('data-supermod-blocked', enabled && isShort(location));
    const next = new Set();
    if (enabled) {
      const shortsSections = new Set();
      for (const item of document.querySelectorAll(shelves + ', ' + tiles)) {
        // Search shelves can use a creator title instead of the word "Shorts".
        // Collapse their layout only when they contain no regular video results.
        next.add(item);
        const section = item.closest(sections);
        if (section) shortsSections.add(section);
      }
      for (const card of document.querySelectorAll('ytm-video-with-context-renderer')) {
        if (!isShortsCard(card)) continue;
        next.add(card);
        const section = card.closest(sections);
        if (section) shortsSections.add(section);
      }
      for (const heading of document.querySelectorAll(headings)) {
        if (heading.textContent.trim().toLowerCase() !== 'shorts') continue;
        next.add(heading);
        const section = heading.closest(sections);
        if (section) shortsSections.add(section);
      }
      for (const section of shortsSections) if (!hasRegularVideos(section)) next.add(section);
      // Mobile YouTube also uses JavaScript-backed pivot items with no href.
      for (const item of document.querySelectorAll(navigation + ', ytm-pivot-bar-renderer [role="tab"]')) {
        const labels = [item, ...item.querySelectorAll('[aria-label], [title]')]
          .flatMap(node => [node.getAttribute('aria-label'), node.getAttribute('title')]);
        if (labels.some(label => label?.trim().toLowerCase() === 'shorts') ||
            item.textContent.trim().toLowerCase() === 'shorts') {
          next.add(item.closest(navigation) ?? item);
        }
      }
      for (const anchor of document.querySelectorAll('a[href*="/shorts"]')) {
        let destination;
        try { destination = new URL(anchor.getAttribute('href'), location.href); } catch { continue; }
        if (!isShort(destination) || anchor.closest('[role="dialog"]')) continue;
        next.add(anchor.closest(navigation + ', ' + tiles) ?? anchor);
      }
    }
    for (const item of marked) if (!next.has(item)) item.classList.remove('supermod-hidden');
    for (const item of next) if (!marked.has(item)) item.classList.add('supermod-hidden');
    marked = next;
  }

  function checkRoute() {
    if (path === location.pathname) return;
    path = location.pathname;
    scan();
    globalThis.webkit?.messageHandlers?.supermod?.postMessage('route');
  }

  for (const event of ['supermod:route', 'popstate', 'hashchange']) window.addEventListener(event, checkRoute);
  new MutationObserver(() => {
    if (!hidden.has('reels') || pending) return;
    pending = true;
    setTimeout(scan, 35);
  }).observe(document, {
    childList: true, subtree: true, characterData: true, attributes: true,
    attributeFilter: ['href', 'aria-label', 'title', 'role']
  });

  globalThis.supermodApply = value => {
    hidden = new Set(value);
    scan();
    return true;
  };
  globalThis.supermodPageState = () => document.querySelector('ytm-app, ytd-app, video') ? 'connected' : 'uncertain';
  scan();
})();
