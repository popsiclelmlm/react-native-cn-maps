import { useEffect } from 'react';

const warned = new Set<string>();

/**
 * In `__DEV__`, log a one-time `console.warn` the first time a not-yet-
 * implemented component mounts. Dedup is module-scope, so subsequent
 * mounts of the same component are silent.
 */
export function useWarnNotImplemented(componentName: string) {
  useEffect(() => {
    if (!__DEV__) {
      return;
    }
    if (warned.has(componentName)) {
      return;
    }
    warned.add(componentName);
    console.warn(
      `[react-native-cn-maps] <${componentName} /> is an M1 stub and renders nothing yet. Track progress in docs/ROADMAP.md.`
    );
  }, [componentName]);
}

/** Test-only: reset the dedup set between cases. */
export function __resetWarningsForTests() {
  warned.clear();
}
