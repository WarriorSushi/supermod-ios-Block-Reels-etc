// This page-world shim sends only a DOM signal. It has no native bridge.
(() => {
  const signal = () => window.dispatchEvent(new Event('supermod:route'));
  for (const name of ['pushState', 'replaceState']) {
    const original = history[name];
    history[name] = function (...args) {
      const result = Reflect.apply(original, this, args);
      signal();
      return result;
    };
  }
})();
