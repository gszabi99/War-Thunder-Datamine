local function mkVersionFromString(version){
  if (version.indexof("_") != null) {
    version = version.split("_")
    assert(version.len()==4, "_ case, version should have 4 digits")
    return version
  }
  else if (version.indexof(".") != null) {
    version = version.split(".")
    assert(version.len()==4, ". case, version should have 4 digits")
    return version
  }
  return null
}

local function mkVersionFromInt(version){
  ::assert(version.len()==4)
  return [version>>24, ((version>>16)&255), ((version>>8)&255), (version&255)]
}

local function versionToInt(version){
  return ((version[0]).tointeger() << 24) | ((version[1]).tointeger() << 16) | ((version[2]).tointeger() << 8) | (version[3]).tointeger()
}

local class Version {
  version = null
  constructor(v){
    local t = ::type(v)

    if (t == "string")
      version = mkVersionFromString(v)
    else if (t == "array") {
      ::assert(v.len()==4)
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
      ::assert(false, "type is not supported")
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
  Version = Version
  versionToInt = versionToInt
  mkVersionFromInt = mkVersionFromInt
  mkVersionFromString = mkVersionFromString
}
