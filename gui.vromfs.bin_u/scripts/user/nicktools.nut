from "%scripts/dagui_library.nut" import *

let { cutPrefix, cutPostfix } = require("%sqstd/string.nut")
let regexp2 = require("regexp2")

let STEAM_PLAYER_POSTFIX = "@steam"

let EPIC_PLAYER_POSTFIX = "@epic"

let XBOX_ONE_PLAYER_PREFIX = "^"
let XBOX_ONE_PLAYER_POSTFIX = "@live"

let PSN_PLAYER_PREFIX = "*"
let PSN_PLAYER_POSTFIX = "@psn"

let xboxPrefixNameRegexp = regexp2($"^['{XBOX_ONE_PLAYER_PREFIX}']")
let xboxPostfixNameRegexp = regexp2($".+({XBOX_ONE_PLAYER_POSTFIX})")
let isXBoxPlayerName = @(name) xboxPrefixNameRegexp.match(name) || xboxPostfixNameRegexp.match(name)

let psnPrefixNameRegexp = regexp2($"^['{PSN_PLAYER_PREFIX}']")
let psnPostfixNameRegexp = regexp2($".+({PSN_PLAYER_POSTFIX})")
let isPS4PlayerName = @(name) psnPrefixNameRegexp.match(name) || psnPostfixNameRegexp.match(name)

let steamPostfixNameRegexp = regexp2($".+({STEAM_PLAYER_POSTFIX})")

let epicPostfixNameRegexp = regexp2($".+({EPIC_PLAYER_POSTFIX})")

let cutPlayerNamePrefix = @(name) cutPrefix(name, PSN_PLAYER_PREFIX,
                                    cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
let cutPlayerNamePostfix = @(name) cutPostfix(name, PSN_PLAYER_POSTFIX,
                                     cutPostfix(name, XBOX_ONE_PLAYER_POSTFIX,
                                     cutPostfix(name, STEAM_PLAYER_POSTFIX,
                                     cutPostfix(name, EPIC_PLAYER_POSTFIX, name))))

return {
  xboxPrefixNameRegexp
  xboxPostfixNameRegexp
  isXBoxPlayerName
  psnPrefixNameRegexp
  psnPostfixNameRegexp
  isPS4PlayerName
  steamPostfixNameRegexp
  epicPostfixNameRegexp
  cutPlayerNamePrefix
  cutPlayerNamePostfix
}