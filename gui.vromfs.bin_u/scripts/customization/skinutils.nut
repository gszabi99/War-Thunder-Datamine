from "%scripts/dagui_library.nut" import *
let regexp2 = require("regexp2")

const DEFAULT_SKIN_NAME = "default"

let unitNameReg = regexp2(@"[.*/].+")
let skinNameReg = regexp2(@"^[^/]*/")

let getSkinId           = @(unitName, skinName) $"{unitName}/{skinName}"
let getPlaneBySkinId    = @(id) unitNameReg.replace("", id)
let getSkinNameBySkinId = @(id) skinNameReg.replace("", id)
let isDefaultSkin       = @(id) getSkinNameBySkinId(id) == DEFAULT_SKIN_NAME

return {
  getSkinId
  getPlaneBySkinId
  getSkinNameBySkinId
  isDefaultSkin
  DEFAULT_SKIN_NAME
}