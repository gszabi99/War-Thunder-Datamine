let extData = {}

let function update(config) {
  foreach (name, value in config) {
    let watch = extData?[name]
    if (watch == null)
      continue

    watch(value)
  }
}

let function make(name, ctor) {
  if (name in extData) {
    ::assert(false, $"extWatched: duplicate name: {name}")
    return extData[name]
  }

  let res = Watched(ctor())
  extData[name] <- res
  res.whiteListMutatorClosure(update)
  return res
}

::interop.updateExtWatched <- update

return make