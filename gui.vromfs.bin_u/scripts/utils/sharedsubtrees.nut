from "math" import deep_hash
from "types" import Float, Table, Array

let sharedSubtrees = {}

function isSameShallow(a, b) {
  if (type(a) != type(b) || a.$len() != b.$len())
    return false
  let keysB = a instanceof Table ? b.$keys() : null
  local idx = 0
  foreach (key, value in a) {
    if (keysB != null && keysB[idx++] != key) 
      return false
    let other = b[key]
    if (value != other || type(value) != type(other)
        || (value instanceof Float && value == 0 && $"{value}" != $"{other}")) 
      return false
  }
  return true
}

function shareSubtree(value) {
  if (!(value instanceof Table) && !(value instanceof Array))
    return value
  let shared = clone value 
  foreach (key, item in value)
    if (item instanceof Table || item instanceof Array)
      shared[key] = callee()(item)
  let hash = deep_hash(shared)
  let pooled = sharedSubtrees?[hash]
  if (pooled != null && isSameShallow(pooled, shared))
    return pooled
  let res = freeze(shared)
  if (pooled == null)
    sharedSubtrees[hash] <- res.$weakref()
  return res
}

return freeze({
  shareSubtree
  clearSharedSubtrees = @() sharedSubtrees.clear()
})
