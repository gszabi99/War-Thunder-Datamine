from "string" import format
from "types" import Function, String

let u = require("u.nut")






















local assertFunc = function(_contextDbgName, errorText) { throw(errorText) }
local getDbgName = @(context) type(context)

function callIfValid(origin_this, ...) {
  try {
    if (!this.isValid())
      return
    return this.callbackFn.acall([origin_this].extend(vargv))
  }
  catch (err) {
    assertFunc(this.getContextDbgName(), err)
  }
}

local Callback = class {
  refToContext = null
  hasContext = false
  callbackFn = null

  isToStringForDebug = true

  constructor(callback_function, context = null) {
    this.callbackFn = callback_function

    if (context)
      this.setContext(context)
  }

  function setContext(context) {
    this.callbackFn = this.callbackFn.bindenv(context)
    this.refToContext = context.weakref()
    this.hasContext = true
  }

  function isValid() {
    if (!this.hasContext)
      return true

    if (this.refToContext == null)
      return false

    if ("isValid" in this.refToContext)
      return this.refToContext.isValid()

    return true
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

  _call = callIfValid
  call = callIfValid

  isEqual = @(other) this == other 
  isEmpty = @() false
  _typeof = @() "Callback"
}

function make(func, context = null) {
  if (u.isOfClass(func, Callback))
    return func
  if (func instanceof Function)
    return Callback(func, context)
  if (func instanceof String && (func in context) && context[func] instanceof Function)
    return Callback(context[func], context)
  return null
}

return freeze({
  Callback
  setAssertFunction = @(func) assertFunc = func  
  reportError = @(assertText, contextDbgName = "null") assertFunc(contextDbgName, assertText)
  setContextDbgNameFunction = @(func) getDbgName = func  
  make
})