/**
 * Function require_native is wrapper function for require. It provides
 * fall back logic when required native module is not exist.
 * If native module failed to load, insted, load script module with
 * same API from nativeModuleCompatibility folder, to provide native
 * module back compatibility.
 * If fallback module has slots, missed in native module, they will
 * be added to result.
 */


::require_native <- function require_native(moduleName) {
  local module = require_optional(moduleName) || {}
  local fallBack = require_optional("nativeModuleCompatibility/" + moduleName + ".nut") ?? {}
  foreach (slotName, slot in fallBack) {
    if (!(slotName in module)) {
      module[slotName] <- slot
    }
  }
  return module
}
