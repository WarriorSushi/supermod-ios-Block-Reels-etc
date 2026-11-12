// Runs in the page world before Instagram's bootstrap scripts. Only the home
// timeline connection is changed; profile, inbox, search and post data pass through.
(() => {
  'use strict';
  if (location.protocol !== 'https:' || !['instagram.com', 'www.instagram.com', 'm.instagram.com'].includes(location.hostname)) return;
  let hidden = new Set(globalThis.supermodFeedBootstrap ?? []);
  delete globalThis.supermodFeedBootstrap;
  const connectionKey = 'xdt_api__v1__feed__timeline__connection';
  const originalParse = JSON.parse;
  let lastPage = null;
  let neededSince = null;
  let automaticPages = 0;
  let requestedAt = null;

  function excludes(edge) {
    const node = edge?.node;
    if (node?.__typename !== 'XDTFeedItem') return false;
    const ad = node.ad || node.explore_story?.ad || node.ad4ad_in_webfeed;
    if (ad) return hidden.has('sponsored');
    return hidden.has('suggestions') && !!(node.explore_story?.media || node.suggested_users);
  }

  function filterConnections(value, seen = new WeakSet()) {
    if (!value || typeof value !== 'object' || seen.has(value)) return;
    seen.add(value);
    // Includes RelayPrefetchedStreamCache's nested initial bootstrap as well as
    // subsequent GraphQL pages. Never infer recommendations from caption text.
    const connection = value[connectionKey];
    if (connection && Array.isArray(connection.edges) && connection.page_info &&
        typeof connection.page_info.has_next_page === 'boolean') {
      const received = connection.edges.length;
      connection.edges = connection.edges.filter(edge => !excludes(edge));
      lastPage = {next: connection.page_info.has_next_page, removed: received - connection.edges.length, at: Date.now()};
      requestedAt = null;
      // Keep the server's cursors and has_next_page, including an all-filtered page.
    }
    for (const [key, child] of Object.entries(value)) {
      if (key !== connectionKey) filterConnections(child, seen);
    }
  }

  JSON.parse = function parse(text, reviver) {
    const result = Reflect.apply(originalParse, this, arguments);
    if (typeof text === 'string' && text.includes(connectionKey)) filterConnections(result);
    return result;
  };

  function homeIsUsable() {
    return location.pathname === '/' && !document.querySelector(
      'input[type="password"],textarea:focus,input:focus,[contenteditable="true"]:focus,dialog[open],[role="dialog"]:not([hidden]):not([aria-hidden="true"])');
  }

  // The inspected Instagram virtual feed can leave its spinner mounted with
  // hasNextPage=true/isFetching=false when filtering makes the first page short.
  // Reuse that feed's own paginator; never replay requests, edit cursors or move
  // scroll position. An unfamiliar component is left alone with a Refresh action.
  function controllerFor(element) {
    const key = Object.keys(element ?? {}).find(key => key.startsWith('__reactFiber$'));
    for (let fiber = key && element[key], depth = 0; fiber && depth < 24; fiber = fiber.return, depth++) {
      const name = fiber.type?.displayName || fiber.type?.name || '';
      const props = fiber.memoizedProps;
      if (name.endsWith('[from PolarisGenericVirtualFeed.react]') &&
          Array.isArray(props?.items) && typeof props.hasNextPage === 'boolean' &&
          typeof props.isFetching === 'boolean' && typeof props.onNextPage === 'function') return props;
    }
    return null;
  }

  function feedContext() {
    if (!homeIsUsable()) return null;
    const main = document.querySelector('main');
    if (!main) return null;
    const spinner = main.querySelector('svg[aria-label="Loading..."],[role="progressbar"]');
    const articles = main.querySelectorAll('article');
    const last = articles[articles.length - 1];
    const controller = controllerFor(spinner || last);
    const bottom = last?.getBoundingClientRect().bottom ?? 0;
    const nearEnd = bottom < innerHeight + 160 &&
      (!spinner || spinner.getBoundingClientRect().top < innerHeight + 160);
    return {controller, spinner, nearEnd, room: innerHeight - Math.max(0, bottom)};
  }

  function requestNext(context, automatic) {
    const controller = context?.controller;
    if (!context?.nearEnd || !controller?.hasNextPage || controller.isFetching ||
        (requestedAt !== null && Date.now() - requestedAt < 15000)) return false;
    if (automatic && automaticPages >= 3) return false;
    requestedAt = Date.now();
    if (automatic) automaticPages++;
    try { controller.onNextPage(); return true; }
    catch { requestedAt = null; return false; }
  }

  globalThis.supermodLoadMoreFeed = () => {
    const context = feedContext();
    if (hidden.has('feed') || !context) return false;
    const requested = requestNext(context, false);
    if (requested) neededSince = Date.now();
    return requested;
  };

  globalThis.supermodFeedStatus = () => {
    const context = feedContext();
    if (!context) { neededSince = null; return null; }
    const filtered = hidden.has('suggestions') || hidden.has('sponsored');
    if (hidden.has('feed')) return {state:'hidden', filtered};
    if (!context.nearEnd) { neededSince = null; automaticPages = 0; return null; }
    const now = Date.now();
    if (neededSince === null) neededSince = now;
    const terminal = lastPage?.next === false || context.controller?.hasNextPage === false;
    if (terminal) return context.room >= 230 ? {state:'end', filtered} : null;
    // Give Instagram's normal prefetch a chance first. At most three automatic
    // pages per empty stretch, and never another while a request is outstanding.
    const elapsed = now - neededSince;
    if (filtered && elapsed >= 1000 && elapsed < 15000 && requestedAt === null) requestNext(context, true);
    if (context.room < 230) return null;
    if (!context.spinner && !context.controller && !lastPage) return null;
    return {state:elapsed >= 15000 ? 'stalled' : 'loading', filtered};
  };

  globalThis.supermodConfigureFeed = next => {
    if (!Array.isArray(next)) return false;
    const selection = new Set(next);
    const changed = ['suggestions', 'sponsored'].some(mod => hidden.has(mod) !== selection.has(mod));
    hidden = selection;
    return changed;
  };
})();
