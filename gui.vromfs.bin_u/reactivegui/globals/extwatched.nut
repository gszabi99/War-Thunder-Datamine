local extData = {}

local function update(config) {
  foreach (name, value in config) {
    local watch = extData?[name]
    if (watch == null)
      continue

    watch(value)
  }
}

local function make(name, ctor) {
  if (name in extData) {
    ::assert(false, $"extWatched: duplicate name: {name}")
    return extData[name]
  }

  local res = Watched(ctor())
  extData[name] <- res
  res.whiteListMutatorClosure(update)
  return res
}

::interop.updateExtWatched <- update

return make