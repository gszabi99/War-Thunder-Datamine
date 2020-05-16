local extData = {}

local function update(config) {
  foreach (name, value in config) {
    local watch = extData?[name]
    if (watch == null)
      continue

    watch(value)
  }
}

local key = {}
local persist = this.persist
local function make(name, ctor) {
  if (name in extData) {
    ::assert(false, $"extWatched: duplicate name: {name}")
    return extData[name]
  }

  local res = persist(name, @() Watched(key))
  extData[name] <- res
  if (res.value == key)
    res(ctor())

  res.whiteListMutatorClosure(update)
  return res
}

::interop.updateExtWatched <- update

return make