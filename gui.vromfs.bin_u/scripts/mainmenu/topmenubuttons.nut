local cache = { byId = {} }

local buttonsListWatch = ::Watched({})

local getButtonConfigById = function(id) {
  if (!(id in cache.byId)) {
    local buttonCfg = buttonsListWatch.value.findvalue(@(t) t.id == id)
    cache.byId[id] <- buttonCfg ?? buttonsListWatch.value.UNKNOWN
  }
  return cache.byId[id]
}

return {
  buttonsListWatch = buttonsListWatch
  getButtonConfigById = getButtonConfigById
}
