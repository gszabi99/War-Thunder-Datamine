local { cutPrefix, cutPostfix } = require("std/string.nut")
local regexp2 = require("regexp2")

local STEAM_PLAYER_POSTFIX = "@steam"

local EPIC_PLAYER_POSTFIX = "@epic"

local XBOX_ONE_PLAYER_PREFIX = "^"
local XBOX_ONE_PLAYER_POSTFIX = "@live"

local PSN_PLAYER_PREFIX = "*"
local PSN_PLAYER_POSTFIX = "@psn"

local xboxPrefixNameRegexp = regexp2($"^['{XBOX_ONE_PLAYER_PREFIX}']")
local xboxPostfixNameRegexp = regexp2($".+({XBOX_ONE_PLAYER_POSTFIX})")
local isXBoxPlayerName = @(name) xboxPrefixNameRegexp.match(name) || xboxPostfixNameRegexp.match(name)

local psnPrefixNameRegexp = regexp2($"^['{PSN_PLAYER_PREFIX}']")
local psnPostfixNameRegexp = regexp2($".+({PSN_PLAYER_POSTFIX})")
local isPS4PlayerName = @(name) psnPrefixNameRegexp.match(name) || psnPostfixNameRegexp.match(name)

local steamPostfixNameRegexp = regexp2($".+({STEAM_PLAYER_POSTFIX})")

local epicPostfixNameRegexp = regexp2($".+({EPIC_PLAYER_POSTFIX})")

local cutPlayerNamePrefix = @(name) cutPrefix(name, PSN_PLAYER_PREFIX,
                                    cutPrefix(name, XBOX_ONE_PLAYER_PREFIX, name))
local cutPlayerNamePostfix = @(name) cutPostfix(name, PSN_PLAYER_POSTFIX,
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