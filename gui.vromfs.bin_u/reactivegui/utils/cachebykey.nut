function cacheByKey(mk) {
  let cache = {}
  return function(key) {
    if (key not in cache)
      cache[key] <- mk(key)
    return cache[key]
  }
}

return freeze({
  cacheByKey
})
