local configId = 0

let configs = {}

let function stashBhvValueConfig(config) {
 configId++
 configs[configId] <- config
 return configId
}

let function popBhvValueConfig(id) {
  return configs.rawdelete(id)
}

return {
  stashBhvValueConfig = stashBhvValueConfig
  popBhvValueConfig = popBhvValueConfig
}