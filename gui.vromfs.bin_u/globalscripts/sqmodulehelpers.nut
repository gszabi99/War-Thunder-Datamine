#explicit-this
#no-root-fallback
/**
 * Function require_native is wrapper function for require. It provides
 * fall back logic when required native module is not exist.
 * If native module failed to load, insted, load script module with
 * same API from nativeModuleCompatibility folder, to provide native
 * module back compatibility.
 * If fallback module has slots, missed in native module, they will
 * be added to result.
 */

let require_native = function require_native(moduleName) {
  let module = require_optional(moduleName) || {}
  let fallBack = require_optional($"%nativeModuleCompatibility/{moduleName}.nut") ?? {}
  foreach (slotName, slot in fallBack) {
    if (!(slotName in module)) {
      module[slotName] <- slot
    }
  }
  return module
}
return {require_native}