
let { format } = require("string")
let u = require("u.nut")

/**
 * Callback - wrapper for regular callback functions with context validation.
 *
 * Usage:
 *   Callback(callback_function(<argumanets>) { ... }, context)
 *     @callback_function - function itself
 *     @context - callbacks environment. Root table is used by default
 *
 *   isValid()
 *     Return true if callback can be called
 *
 *   markInvalid()
 *     Callback may be set invalid manually
 *
 *   static function make(func, context = null)
 *     try to create Callback from anything. return null if failed.
 *     func - can be Callback, function, or string function name in context
 *
 * Context validations:
 *   If context specified it will be validated before calling. If context has
 *   function isValid(), result of this funtion will determine validity of
 *   Callback.
 */

local assertFunc = function(_callback, errorText) { throw(errorText) }
local getDbgName = @(context) type(context)

local Callback = class {
  refToContext = null
  hasContext = false
  callbackFn = null
  valid = true

  isToStringForDebug = true

  constructor(callback_function, context = null) {
    this.callbackFn = callback_function

    if (context)
      this.setContext(context)

    this.valid = true
  }

  function setContext(context) {
    this.callbackFn = this.callbackFn.bindenv(context)
    this.refToContext = context.weakref()
    this.hasContext = true
  }

  function isValid() {
    return this.isContextValid() && this.valid
  }

  function markInvalid() {
    this.valid = false
  }

  function getContextDbgName() {
    if (!this.hasContext)
      return "null"
    return getDbgName(this.refToContext)
  }

  function getfuncinfos() {
    return this.callbackFn.getfuncinfos()
  }

  function tostring() {
    return format("Callback( context = %s)", this.getContextDbgName())
  }

  /**
   * Check Call a callback function
   */
  function _call(origin_this, ...) {
    try {
      if (!this.isContextValid())
        return
      return this.callbackFn.acall([origin_this].extend(vargv))
    }
    catch (err) {
      assertFunc(this, err)
    }
  }

  /**
   * Check Call a callback function
   */
  function call(origin_this, ...) {
    try {
      if (!this.isContextValid())
        return
      return this.callbackFn.acall([origin_this].extend(vargv))
    }
    catch (err) {
      assertFunc(this, err)
    }
  }

  /***************************** Private methods ******************************/

  function isContextValid() {
    if (!this.hasContext)
      return true

    if (this.refToContext == null)
      return false

    if ("isValid" in this.refToContext)
      return this.refToContext.isValid()

    return true
  }
}

function make(func, context = null) {
  if (u.isCallback(func))
    return func
  if (type(func) == "function")
    return Callback(func, context)
  if (type(func) == "string" && (func in context) && type(context[func]) == "function")
    return Callback(context[func], context)
  return null
}

u.registerClass("Callback", Callback)

return {
  Callback
  setAssertFunction = @(func) assertFunc = func  //void func(callback, assertText)
  setContextDbgNameFunction = @(func) getDbgName = func  //string func(context)
  make
}