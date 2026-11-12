// Always-on browser polish, independent of optional feed modifications.
(() => {
  'use strict';
  const config = globalThis.supermodBootstrap;
  const hosts = /^(www\.|m\.)?(instagram|facebook|youtube)\.com$/;
  if (!config || (!config.fixture && (location.protocol !== 'https:' || !hosts.test(location.hostname)))) return;
  const controls = 'a[href],button,[role="button"]';
  const protectedContent = 'article,[role="article"],[data-pagelet^="FeedUnit_"],form,[contenteditable="true"],[role="textbox"]';
  const promoLabel = /^(?:use (?:the |our )?app|open(?: in)? (?:the )?(?:(?:instagram|facebook|youtube) )?app|open (?:instagram|facebook|youtube)|get (?:the )?(?:(?:instagram|facebook|youtube) )?app|install(?: (?:the )?(?:instagram|facebook|youtube)(?: app)?)?|continue in (?:the )?app)$/i;
  const normalize = value => (value ?? '').replace(/[\u200b-\u200f]/g, '').trim().replace(/\s+/g, ' ');
  const promos = new Set();
  let style;
  const roots = new Set();
  let timer = 0;
  function promoContainer(control) {
    if (control.closest(protectedContent)) return null;
    const appLink = /^(?:https:\/\/(?:apps\.apple\.com\/|play\.google\.com\/store\/apps)|(?:instagram|fb|facebook|youtube):\/\/)/i.test(control.getAttribute('href') ?? '');
    if (!appLink && ![control.textContent, control.getAttribute('aria-label')].some(text => promoLabel.test(normalize(text)))) return null;
    // Require a bounded overlay: never hide ordinary post text or a login form.
    for (let node = control, depth = 0; node && node !== document.body && depth < 7; node = node.parentElement, depth++) {
      if (node.matches('nav,[role="navigation"],main') || node.querySelector('article,form,input,textarea,[contenteditable="true"],video')) break;
      if (node.textContent.length > 600 || node.querySelectorAll(controls).length > 5) break;
      const position = getComputedStyle(node).position;
      if (position === 'fixed' || position === 'sticky' || node.matches('[role="dialog"],ytm-app-promo-renderer')) return node;
    }
    return null;
  }
  function installStyle() {
    if (!document.documentElement || style?.isConnected) return;
    style = document.createElement('style');
    style.textContent = '.supermod-app-promo { display:none !important; }';
    (document.head ?? document.documentElement).append(style);
  }
  function scan(root) {
    if (!root?.isConnected) return;
    installStyle();
    if (root.matches('meta[name="apple-itunes-app"]')) root.remove();
    root.querySelectorAll('meta[name="apple-itunes-app"]').forEach(meta => meta.remove());
    const candidates = [...root.querySelectorAll(controls)];
    if (root.matches(controls)) candidates.push(root);
    const parentControl = root.closest(controls);
    if (parentControl) candidates.push(parentControl);
    for (const control of candidates) {
      const container = promoContainer(control);
      if (container) { promos.add(container); if (!container.classList.contains('supermod-app-promo')) container.classList.add('supermod-app-promo'); }
    }
  }
  function flush() {
    timer = 0;
    // Virtualized sites reuse nodes. Restore a container if its promo disappears.
    for (const node of promos) {
      if (!node.isConnected) { promos.delete(node); continue; }
      if (![node, ...node.querySelectorAll(controls)].some(control => control.matches(controls) && promoContainer(control) === node)) {
        node.classList.remove('supermod-app-promo'); promos.delete(node);
      }
    }
    const batch = new Set(roots); roots.clear();
    for (const root of batch) {
      let covered = false;
      for (let parent = root.parentElement; parent; parent = parent.parentElement) {
        if (batch.has(parent)) { covered = true; break; }
      }
      if (!covered) scan(root);
    }
  }
  const observer = new MutationObserver(records => {
    for (const record of records) {
      if (record.target === style || record.target.parentElement === style) continue;
      const node = record.target.nodeType === 1 ? record.target : record.target.parentElement;
      if (record.type === 'attributes' && ['class', 'style'].includes(record.attributeName)) {
        if (node?.closest(protectedContent) || node === document.body || node === document.documentElement) continue;
        if (record.attributeName === 'class') {
          const externalClasses = value => (value ?? '').split(/\s+/).filter(name => !name.startsWith('supermod-')).join(' ');
          if (externalClasses(record.oldValue) === externalClasses(node.getAttribute('class'))) continue;
        }
      }
      if (record.type !== 'childList' && node) roots.add(node);
      for (const added of record.addedNodes) {
        if (added.nodeType === 1 && added !== style) roots.add(added);
        else if (added.nodeType === 3 && node) roots.add(node);
      }
      if (record.removedNodes.length && node?.closest('.supermod-app-promo')) roots.add(node);
    }
    if (roots.size && !timer) timer = setTimeout(flush, 16);
  });
  function start() {
    installStyle();
    scan(document.documentElement);
    observer.observe(document, {subtree: true, childList: true, characterData: true, attributes: true,
      attributeOldValue: true, attributeFilter: ['href', 'aria-label', 'role', 'class', 'style']});
  }
  // Only intentional controls generate a native haptic, never scrolling or typing.
  document.addEventListener('click', event => {
    if (!event.isTrusted || event.defaultPrevented || !(event.target instanceof Element)) return;
    const control = event.target.closest(controls + ',[role="tab"],[role="checkbox"],[role="switch"]');
    if (!control || control.matches(':disabled,[aria-disabled="true"]') || control.closest('.supermod-app-promo')) return;
    globalThis.webkit?.messageHandlers?.supermod?.postMessage('haptic');
  });
  if (document.documentElement) start();
  else document.addEventListener('DOMContentLoaded', start, {once: true});
  document.addEventListener('DOMContentLoaded', () => scan(document.documentElement), {once: true});
  window.addEventListener('load', () => scan(document.documentElement), {once: true});
  window.addEventListener('supermod:route', () => scan(document.documentElement));
  window.addEventListener('pageshow', start);
  window.addEventListener('pagehide', () => { observer.disconnect(); clearTimeout(timer); timer = 0; roots.clear(); });
})();
