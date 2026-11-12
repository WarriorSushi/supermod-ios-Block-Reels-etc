(() => {
  'use strict';
  let {hidden, rules, css, fixture} = globalThis.supermodBootstrap;
  const hosts = new Set(['instagram.com', 'www.instagram.com', 'm.instagram.com']);
  const authentication = new Set(['accounts', 'challenge', 'checkpoint', 'consent', 'oauth', 'privacy', 'two_factor']);
  const first = url => {
    const segment = url.pathname.split('/').find(Boolean) ?? '';
    try { return decodeURIComponent(segment).toLowerCase(); }
    catch { return ''; }
  };
  const owned = url => url.protocol === 'https:' && !url.port && !url.username && !url.password && hosts.has(url.hostname);
  const pathMod = url => {
    if (!owned(url)) return null;
    switch (first(url)) {
      case 'reels':
      case 'reel': return 'reels';
      case 'explore': return 'explore';
      case 'stories': return 'stories';
      default: return null;
    }
  };
  const anchorMod = anchor => {
    try { return pathMod(new URL(anchor.href)); }
    catch { return null; }
  };
  const navigationLink = 'nav a[href],[role="navigation"] a[href],a[role="link"][href]';
  function shortcutMod(anchor) {
    const mod = anchorMod(anchor);
    if (!mod) return null;
    if (anchor.closest('nav,[role="navigation"]')) return mod;
    // Instagram's mobile toolbar uses icon links in plain divs.
    if ((mod === 'reels' || mod === 'explore') &&
        new URL(anchor.href).pathname.replace(/\/+$/, '') === '/' + mod &&
        anchor.querySelector('svg[aria-label]')) return mod;
    return null;
  }

  function isStoriesTray(scroller) {
    const rail = scroller?.firstElementChild;
    if (scroller?.childElementCount !== 1 ||
        !['auto', 'scroll'].includes(getComputedStyle(scroller).overflowX)) return false;
    // The mobile tray starts with an add-story tile. Require its exact label
    // inside the horizontal rail so other carousels and post text stay visible.
    return [...rail.querySelectorAll(':scope > [role="button"] span')].some(span =>
      !span.childElementCount && /^your story$/i.test(span.textContent.trim()));
  }

  function isSingleChildWrapper(element) {
    return element?.matches('div:not([role],[aria-label]),span:not([role],[aria-label])') &&
      element.childElementCount === 1 &&
      ![...element.childNodes].some(node => node.nodeType === 3 && node.textContent.trim());
  }

  function slotFor(element) {
    // Collapse the empty layout slot along with its only control.
    while (isSingleChildWrapper(element.parentElement)) element = element.parentElement;
    return element;
  }

  function hasMobileBadge(article, pattern) {
    let layout = article;
    while (layout.childElementCount === 1 && layout.firstElementChild.matches('div,span')) {
      layout = layout.firstElementChild;
    }
    // The first branch contains the author and the badge below their name.
    const header = layout.firstElementChild;
    if (layout.childElementCount < 2 || !header?.querySelector('a[href],[role="link"],img')) return false;
    return [...header.querySelectorAll('span')].some(span => {
      if (span.childElementCount || span.closest('a,button,[role="link"]')) return false;
      if (!pattern.test(span.textContent.trim())) return false;
      for (let label = span; label !== header; label = label.parentElement) {
        if (label.previousElementSibling?.textContent.trim()) return true;
      }
      return false;
    });
  }
  const mobileBadges = {sponsored: /^(ad|sponsored)$/i, suggestions: /^suggested for you$/i};
  function matchesFeedRule(element, mod) {
    if (rules.elements[mod] && element.matches(rules.elements[mod])) return true;
    if (!element.matches('main article')) return false;
    return (rules.markers[mod] && !!element.querySelector(rules.markers[mod])) ||
      (mobileBadges[mod] && hasMobileBadge(element, mobileBadges[mod]));
  }
  const route = () => fixture ? new URL(location.pathname, 'https://www.instagram.com') : new URL(location.href);
  const isLogin = () => {
    const current = first(route());
    if (authentication.has(current)) return true;
    if (current !== '') return false;
    if (document.querySelector('input[type="password"][autocomplete="current-password"]')) return true;
    const login = document.querySelector('a[href^="/accounts/login"],a[href^="https://www.instagram.com/accounts/login"]');
    const inbox = document.querySelector('a[href^="/direct/"],a[href^="https://www.instagram.com/direct/"]');
    return !!login && !inbox;
  };
  const active = () => owned(route()) && !isLogin();
  const tagged = new Set();
  let followSuggestionRows = new Set();
  let queue = new Set();
  let frame = 0;
  let cssNode;
  let lastURL;
  let lastLogin;
  const mark = element => {
    if (!element) return;
    // Timeline data is filtered before Instagram lays out posts. For unfamiliar
    // markup, mask residual content without changing the virtualizer's geometry.
    const suggestion = hidden.includes('suggestions') && matchesFeedRule(element, 'suggestions');
    const sponsored = hidden.includes('sponsored') && matchesFeedRule(element, 'sponsored');
    const preserveSlot = !hidden.includes('feed') && (suggestion || sponsored);
    element.classList.toggle('supermod-filtered-post', !!preserveSlot);
    if (preserveSlot) {
      element.setAttribute('data-supermod-filter-label', sponsored ? 'Sponsored post hidden' : 'Suggested post hidden');
      element.querySelectorAll('video,audio').forEach(media => { if (!media.paused) media.pause(); });
    }
    tagged.add(element);
    element.classList.add('supermod-hidden');
  };
  const unmark = element => {
    element.classList.remove('supermod-hidden', 'supermod-filtered-post');
    element.removeAttribute('data-supermod-filter-label');
  };

  const candidates = (node, selector, callback) => {
    if (node.matches(selector)) callback(node);
    const ancestor = node.closest(selector);
    if (ancestor) callback(ancestor);
    node.querySelectorAll(selector).forEach(callback);
  };

  function shouldHide(element) {
    if (!active()) return false;
    const home = first(route()) === '';
    for (let control = element; control; control = isSingleChildWrapper(control) ? control.firstElementChild : null) {
      if (control.matches(navigationLink) && hidden.includes(shortcutMod(control))) return true;
      if (home && hidden.includes('stories') && isStoriesTray(control)) return true;
    }
    if (!home) return false;
    return hidden.some(mod => matchesFeedRule(element, mod));
  }

  function reconsider(element) {
    if (!element || !tagged.has(element)) return false;
    if (shouldHide(element)) {
      mark(element);
      return false;
    }
    tagged.delete(element);
    unmark(element);
    return true;
  }

  function scan(node) {
    if (!node.isConnected) return;
    const hiddenParent = node.closest('.supermod-hidden');
    if (reconsider(hiddenParent) && hiddenParent !== node) node = hiddenParent;
    node.querySelectorAll('.supermod-hidden').forEach(reconsider);
    if (!active()) return;
    const current = first(route());
    candidates(node, navigationLink, anchor => {
      if (hidden.includes(shortcutMod(anchor))) mark(slotFor(anchor));
    });
    if (current !== '') return;
    if (hidden.includes('sponsored') || hidden.includes('suggestions')) {
      candidates(node, 'main article', article => {
        if (Object.keys(mobileBadges).some(mod => hidden.includes(mod) && matchesFeedRule(article, mod))) mark(article);
      });
    }
    if (hidden.includes('stories')) {
      const scrollers = new Set();
      candidates(node, '[role="button"]', button => scrollers.add(button.parentElement?.parentElement));
      for (const scroller of scrollers) {
        if (isStoriesTray(scroller)) mark(slotFor(scroller));
      }
    }
    for (const mod of hidden) {
      const selector = rules.elements[mod];
      if (selector) candidates(node, selector, mark);
      const marker = rules.markers[mod];
      if (marker) candidates(node, marker, node => mark(node.closest('main article')));
    }
  }

  function updateFollowSuggestions(changed = document.querySelector('main')) {
    const main = hidden.includes('suggestions') && active() && first(route()) === ''
      ? document.querySelector('main') : null;
    if (!main) {
      for (const row of followSuggestionRows) row.classList.remove('supermod-follow-suggestions');
      followSuggestionRows.clear();
      return;
    }
    const excluded = 'article,button,a,form,[role="dialog"],[contenteditable]';
    changed = changed?.closest('.supermod-follow-suggestions') ?? changed;
    if (!changed || changed.closest(excluded)) return;
    let scope = changed;
    if (scope.contains(main)) scope = main;
    else if (!main.contains(scope)) return;
    // Revisit just the changed top-level non-post row. Never walk every caption
    // in the accumulated feed for a like counter, new post, or video update.
    while (scope !== main && scope.parentElement !== main) scope = scope.parentElement;
    for (const row of followSuggestionRows) {
      if (!row.isConnected || scope.contains(row)) {
        row.classList.remove('supermod-follow-suggestions');
        followSuggestionRows.delete(row);
      }
    }
    const walker = document.createTreeWalker(scope, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, {
      acceptNode: node => node.nodeType === 1
        ? (node.matches(excluded) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_SKIP)
        : NodeFilter.FILTER_ACCEPT
    });
    for (let text = walker.nextNode(); text; text = walker.nextNode()) {
      if (!/^suggestions for you$/i.test(text.nodeValue.trim())) continue;
      const heading = text.parentElement;
      for (let row = heading.parentElement; row && row !== main; row = row.parentElement) {
        if (row.querySelector('article,form,[role="dialog"]')) break;
        const controls = [...row.querySelectorAll('button,[role="button"]')];
        const follows = controls.filter(control =>
          (/^follow$/i.test(control.textContent.trim()) ||
           /^follow(?:\s+\S.*)?$/i.test(control.getAttribute('aria-label')?.trim() ?? '')) &&
          !control.parentElement?.closest('button,[role="button"]'));
        if (follows.length < 2) continue;
        followSuggestionRows.add(row);
        row.setAttribute('data-supermod-filter-label', 'Suggestions hidden');
        row.classList.add('supermod-follow-suggestions');
        break;
      }
    }
  }

  function installStyle() {
    const root = document.documentElement;
    if (!root) return;
    if (!cssNode?.isConnected) {
      cssNode = document.createElement('style');
      cssNode.textContent = css;
      (document.head || root).append(cssNode);
    }
    const enabled = active();
    root.toggleAttribute('data-supermod-active', enabled);
    root.toggleAttribute('data-supermod-instagram', enabled);
    root.toggleAttribute('data-supermod-blocked', enabled && hidden.includes(pathMod(route())));
  }

  function report(event) {
    globalThis.webkit?.messageHandlers.supermod?.postMessage(event);
  }

  function refresh() {
    for (const element of tagged) unmark(element);
    tagged.clear();
    installStyle();
    if (document.documentElement) scan(document.documentElement);
    updateFollowSuggestions();
  }

  function routeChanged() {
    if (lastURL === location.href) return;
    lastURL = location.href;
    lastLogin = isLogin();
    refresh();
    report('route');
  }

  const observer = new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes') queue.add(record.target);
      const checksBadgeText = hidden.includes('stories') || hidden.includes('sponsored') || hidden.includes('suggestions');
      const textParent = record.type === 'characterData' ? record.target.parentElement : record.target;
      if (checksBadgeText && textParent?.nodeType === 1 && first(route()) === '' &&
          (record.type === 'characterData' || [...record.addedNodes, ...record.removedNodes].some(node => node.nodeType === 3))) {
        queue.add(textParent);
      }
      if (record.removedNodes.length && record.target.nodeType === 1) {
        const candidate = record.target.closest('.supermod-hidden');
        if (candidate) queue.add(candidate);
      }
      for (const node of record.addedNodes) {
        if (node.nodeType === 1 && node !== cssNode) queue.add(node);
      }
    }
    if (!queue.size || frame) return;
    // Mutation observers run before rendering. Keep filtering in that same
    // microtask checkpoint: a timer lets a newly inserted post paint at full
    // height before collapsing it, flashing content and shifting the feed.
    frame = 1;
    queueMicrotask(() => {
      if (!frame) return;
      frame = 0;
      const batch = queue;
      queue = new Set();
      const login = isLogin();
      if (lastLogin !== login) {
        lastLogin = login;
        refresh();
        report('page-state');
        return;
      }
      installStyle();
      for (const element of tagged) if (!element.isConnected) tagged.delete(element);
      for (const row of followSuggestionRows) if (!row.isConnected) followSuggestionRows.delete(row);
      for (const node of batch) {
        let covered = false;
        for (let parent = node.parentElement; parent; parent = parent.parentElement) {
          if (batch.has(parent)) { covered = true; break; }
        }
        if (covered) continue;
        scan(node);
        updateFollowSuggestions(node);
      }
    });
  });
  function start() {
    installStyle();
    observer.observe(document.documentElement, {
      subtree: true, childList: true, attributes: true, characterData: true,
      attributeFilter: ['href', 'aria-label', 'data-testid', 'data-pagelet', 'role']
    });
    routeChanged();
  }
  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start, {once: true});
  document.addEventListener('DOMContentLoaded', refresh, {once: true});
  window.addEventListener('supermod:route', routeChanged);
  window.addEventListener('popstate', routeChanged);
  window.addEventListener('pageshow', () => { if (document.documentElement) start(); });
  window.addEventListener('pagehide', () => {
    observer.disconnect();
    frame = 0;
    queue.clear();
  });
  document.addEventListener('play', event => {
    if (event.target instanceof HTMLMediaElement && event.target.closest('.supermod-filtered-post')) event.target.pause();
  }, true);
  window.addEventListener('click', event => {
    if (!active() || !(event.target instanceof Element)) return;
    const anchor = event.target.closest('a[href]');
    const mod = anchor ? anchorMod(anchor) : null;
    if (mod && hidden.includes(mod)) {
      event.preventDefault();
      event.stopImmediatePropagation();
      report('blocked:' + mod);
    }
  }, true);
  globalThis.supermodApply = next => {
    if (!Array.isArray(next)) return false;
    hidden = next;
    refresh();
    return true;
  };
  globalThis.supermodPageState = () => {
    if (isLogin()) return 'login';
    const inbox = document.querySelector('a[href^="/direct/"],a[href^="https://www.instagram.com/direct/"]');
    if (!active() || !cssNode?.sheet) return 'uncertain';
    if (inbox || first(route()) === 'direct') return 'connected';
    return document.querySelector('main article, main [role="feed"]') ? 'feed' : 'uncertain';
  };
})();
