// Mocking translation function
global.__ = text => text; // eslint-disable-line

// Mocking locales to prevent unnecessary fallback messages
window.locales = { en: { domain: 'app', locale_data: { app: { '': {} } } } };

// Suppress React warnings about unrecognized DOM props from PatternFly 5.
// PF5 passes custom attributes (ouia*, variant helpers) that React warns
// about. Only suppress known PF5 prop names so real component bugs still
// surface as test failures.
const PF5_KNOWN_PROPS = [
  'ouiaSafe',
  'ouiaId',
  'isExpanded',
  'isDisabled',
  'isActive',
  'isPlain',
  'isInline',
  'isFilled',
  'isCompact',
  'isHovered',
  'isStriped',
  'isStickyHeader',
  'hasRightBorder',
  'hasGutter',
];
const originalConsoleError = console.error; // eslint-disable-line no-console
// eslint-disable-next-line no-console
console.error = (...args) => {
  const message = typeof args[0] === 'string' ? args[0] : '';
  if (message.includes('does not recognize the `%s` prop')) {
    const propName = typeof args[1] === 'string' ? args[1] : '';
    if (PF5_KNOWN_PROPS.includes(propName)) return;
  }
  originalConsoleError.apply(console, args);
  const errorMsg = args
    .map(arg => (typeof arg === 'string' ? arg : JSON.stringify(arg)))
    .join(' ');
  throw new Error(errorMsg || 'console.error was called');
};
