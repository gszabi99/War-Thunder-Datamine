local {logerr} = require("dagor.debug")
local regexp2 = require("regexp2")

local dotCase = regexp2(@"^\d+\.\d+\.\d+\.\d+$")
local dashCase = regexp2(@"^\d+\_\d+\_\d+\_\d+$")

local function mkVersionFromString(version){
  if (dotCase.match(version))
    return version.split(".")
  if (dashCase.match(version))
    return version.split("_")

  logerr($"CHANGELOG: Version string {version} has invalid chars")
  return null
}

local function mkVersionFromInt(version){
  return [version>>24, ((version>>16)&255), ((version>>8)&255), (version&255)]
}

local function versionToInt(version){
  return version
    ? ((version[0]).tointeger() << 24) | ((version[1]).tointeger() << 16)
      | ((version[2]).tointeger() << 8) | (version[3]).tointeger()
    : -1
}

local class Version {
  version = null
  constructor(v){
    local t = type(v)

    if (t == "string")
      version = mkVersionFromString(v)
    else if (t == "array") {
      assert(v.len()==4)
      version = clone v
    }
    else if (t =="integer") {
      version = mkVersionFromInt(v)
    }
    else if (t=="float")
      version = mkVersionFromInt(v.tointeger())
    else if (t=="null")
      version = [0,0,0,0]
    else {
      version = [0,0,0,0]
      assert(false, "type is not supported")
    }
  }
  function toint(){
    return versionToInt(version)
  }

  function tostring(){
    return ".".join(version)
  }
}

return {
  Version
  versionToInt
  mkVersionFromInt
  mkVersionFromString
}
