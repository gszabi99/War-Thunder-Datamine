from "%sqDagui/daguiNativeApi.nut" import *

local configId = 0

let configs = {}

function stashBhvValueConfig(config) {
 configId++
 configs[configId] <- config
 return configId
}

function popBhvValueConfig(id) {
  return configs.rawdelete(id)
}

return {
  stashBhvValueConfig = stashBhvValueConfig
  popBhvValueConfig = popBhvValueConfig
}