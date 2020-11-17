::UrlMission <- class
{
  name = ""
  url = ""
  hasErrorByLoading = false
  isFavorite = false
  fullMissionBlk = null

  saveParamsList = [
    "name"
    "url"
    "isFavorite"
    "hasErrorByLoading"
  ]

  //constructor(name, url) - create new UrlMission with name and url listed in params
  //constructor(DataBlock) - load all params from DataBlock
  constructor(param1, param2 = null)
  {
    if (::u.isDataBlock(param1))
      return loadFromBlk(param1)

    if (::u.isString(param1))
      name = param1
    if (::u.isString(param2))
      url = param2
  }

  function loadFromBlk(blk)
  {
    foreach(key in saveParamsList)
      if (typeof blk?[key] == typeof this[key])
        this[key] = blk[key]
  }

  function getSaveBlk()
  {
    local res = ::DataBlock()
    foreach(key in saveParamsList)
      res[key] = this[key]
    return res
  }

  function getMetaInfo()
  {
    if (fullMissionBlk == null ||
        !("mission_settings" in fullMissionBlk) ||
        !("mission" in fullMissionBlk.mission_settings))
      return null
    else
      return fullMissionBlk.mission_settings.mission
  }

  function isValid()
  {
    return name.len() > 0 && url.len() > 0
  }
}