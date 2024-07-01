from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

let DataBlock = require("DataBlock")

::UrlMission <- class {
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
  constructor(param1, param2 = null) {
    if (u.isDataBlock(param1))
      return this.loadFromBlk(param1)

    if (u.isString(param1))
      this.name = param1
    if (u.isString(param2))
      this.url = param2
  }

  function loadFromBlk(blk) {
    foreach (key in this.saveParamsList)
      if (type(blk?[key]) == type(this[key]))
        this[key] = blk[key]
  }

  function getSaveBlk() {
    let res = DataBlock()
    foreach (key in this.saveParamsList)
      res[key] = this[key]
    return res
  }

  function getMetaInfo() {
    if (this.fullMissionBlk == null ||
        !("mission_settings" in this.fullMissionBlk) ||
        !("mission" in this.fullMissionBlk.mission_settings))
      return null
    else
      return this.fullMissionBlk.mission_settings.mission
  }

  function isValid() {
    return this.name.len() > 0 && this.url.len() > 0
  }
}