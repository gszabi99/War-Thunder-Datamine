local configId = 0

local configs = {}

local function stashBhvValueConfig(config) {
 configId++
 configs[configId] <- config
 return configId
}

local function popBhvValueConfig(id) {
  return configs.rawdelete(id)
}

return {
  stashBhvValueConfig = stashBhvValueConfig
  popBhvValueConfig = popBhvValueConfig
}