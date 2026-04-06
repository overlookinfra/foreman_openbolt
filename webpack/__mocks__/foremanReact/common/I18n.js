// Mock for Foreman's I18n module. The real module depends on jed (gettext)
// and Foreman's runtime locale configuration, which aren't available in
// the plugin test environment. sprintf is mocked with minimal %s/%d
// replacement so rendered strings are testable.
export const translate = text => text;

export const sprintf = (fmt, ...args) => {
  let result = fmt;
  args.forEach(arg => {
    result = result.replace(/%[sd]/, arg);
  });
  return result;
};

export default { translate, sprintf };
