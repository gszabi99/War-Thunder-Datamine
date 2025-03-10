from "%scripts/dagui_natives.nut" import clan_is_role_allowed_for_type, clan_is_upgrade_allowed, clan_get_primary_info_gold_cost_param_name, clan_get_wp_cost_param_name, string_to_clan_type, clan_get_upgrade_wp_cost_param_name, clan_is_desc_allowed_for_type, clan_get_tag_length_limit, clan_type_to_string, clan_get_primary_info_wp_cost_param_name, clan_get_members_upgrade_cost, clan_get_secondary_info_gold_cost_param_name, clan_get_admin_editor_mode, clan_get_upgrade_gold_cost_param_name, clan_get_gold_cost_param_name, clan_is_announcement_allowed_for_type, clan_get_members_upgrade_step, clan_get_secondary_info_wp_cost_param_name
from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")
let { get_warpoints_blk } = require("blkGetters")
let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")

let g_clan_type = {
  types = []
}

g_clan_type._getCreateCost <- function _getCreateCost() {
  let blk = get_warpoints_blk()
  let cost = Cost()
  cost.gold = blk?[clan_get_gold_cost_param_name(this.code)] ?? 0
  cost.wp = blk?[clan_get_wp_cost_param_name(this.code)] ?? 0
  return cost
}

g_clan_type._getPrimaryInfoChangeCost <- function _getPrimaryInfoChangeCost() {
  let blk = get_warpoints_blk()
  let cost = Cost()
  if (!clan_get_admin_editor_mode()) {
    cost.gold = blk?[clan_get_primary_info_gold_cost_param_name(this.code)] ?? 0
    cost.wp = blk?[clan_get_primary_info_wp_cost_param_name(this.code)] ?? 0
  }
  return cost
}

g_clan_type._getSecondaryInfoChangeCost <- function _getSecondaryInfoChangeCost() {
  let blk = get_warpoints_blk()
  let cost = Cost()
  if (!clan_get_admin_editor_mode()) {
    cost.gold = blk?[clan_get_secondary_info_gold_cost_param_name(this.code)] ?? 0
    cost.wp = blk?[clan_get_secondary_info_wp_cost_param_name(this.code)] ?? 0
  }
  return cost
}

g_clan_type._checkTagText <- function _checkTagText(tagText) {
  if (tagText.indexof(this.start) != 0 || tagText.len() < this.end.len())
    return false
  return tagText.slice(-this.end.len()) == this.end
}

g_clan_type._getTagLengthLimit <- function _getTagLengthLimit() {
  return clan_get_tag_length_limit(this.code)
}

g_clan_type._isDescriptionChangeAllowed <- function _isDescriptionChangeAllowed() {
  return clan_is_desc_allowed_for_type(this.code)
}

g_clan_type._isAnnouncementAllowed <- function _isAnnouncementAllowed() {
  return clan_is_announcement_allowed_for_type(this.code)
}

g_clan_type._isRoleAllowed <- function _isRoleAllowed(roleCode) {
  return clan_is_role_allowed_for_type(roleCode, this.code)
}

g_clan_type._getTypeName <- function _getTypeName() {
  return clan_type_to_string(this.code)
}

g_clan_type._isEnabled <- function _isEnabled() {
  return this.getCreateCost().gold != -1
}

g_clan_type._getNextType <- function _getNextType() {
  let nextType = g_clan_type.getTypeByCode(this.nextTypeCode)
  if (nextType == g_clan_type.UNKNOWN || !g_clan_type.isUpgradeAllowed(this, nextType))
    return g_clan_type.UNKNOWN
  return nextType
}

g_clan_type._getNextTypeUpgradeCost <- function _getNextTypeUpgradeCost() {
  return g_clan_type.getUpgradeCost(this, this.getNextType())
}

g_clan_type._canUpgradeMembers <- function _canUpgradeMembers(current_limit) {
  return clan_get_members_upgrade_cost(this.code, current_limit) >= 0
}

g_clan_type._getMembersUpgradeCost <- function _getMembersUpgradeCost(current_limit) {
  return Cost(0, max(0, clan_get_members_upgrade_cost(this.code, current_limit)))
}

g_clan_type._getMembersUpgradeStep <- function _getMembersUpgradeStep() {
  return clan_get_members_upgrade_step(this.code)
}

let g_clan_type_cache = {
  byCode = {}
}

g_clan_type.template <- {
  _createCost = null
  _primaryInfoChangeCost = null
  _secondaryInfoChangeCost = null
  _upgradeCost = null
  _tagDecorators = null

  maxMembers = 0
  maxCandidates = 0
  minMemberCountToWWarParamName = ""

  
  getCreateCost = g_clan_type._getCreateCost

  
  getPrimaryInfoChangeCost = g_clan_type._getPrimaryInfoChangeCost

  
  getSecondaryInfoChangeCost = g_clan_type._getSecondaryInfoChangeCost

  
  getTagLengthLimit = g_clan_type._getTagLengthLimit

  
  isDescriptionChangeAllowed = g_clan_type._isDescriptionChangeAllowed

  
  isAnnouncementAllowed = g_clan_type._isAnnouncementAllowed

  
  isRoleAllowed = g_clan_type._isRoleAllowed

  
  getTypeName = g_clan_type._getTypeName

  
  getTypeNameLoc = @() loc("".concat("clan/clan_type/", clan_type_to_string(this.code)))

  
  isEnabled = g_clan_type._isEnabled

  



  getNextType = g_clan_type._getNextType

  
  getNextTypeUpgradeCost = g_clan_type._getNextTypeUpgradeCost

  
  canUpgradeMembers = g_clan_type._canUpgradeMembers

  
  getMembersUpgradeCost = g_clan_type._getMembersUpgradeCost

  
  getMembersUpgradeStep = g_clan_type._getMembersUpgradeStep

  getMinMemberCountToWWar = @() get_warpoints_blk()?[this.minMemberCountToWWarParamName] ?? 1
}

enumsAddTypes(g_clan_type, {
  NORMAL = {
    code = ECT_NORMAL 
    color = "activeTextColor"
    nextTypeCode = ECT_UNKNOWN
    maxMembers = 128
    maxCandidates = 256
    minMemberCountToWWarParamName = "minClanMembersToRegister"
  }
  BATTALION = {
    code = ECT_BATTALION 
    color = "battalionSquadronColor"
    nextTypeCode = ECT_NORMAL
    maxMembers = 10
    maxCandidates = 20
    minMemberCountToWWarParamName = "minBattalionMembersToRegister"
  }
  UNKNOWN = {
    code = ECT_UNKNOWN 
    color = "activeTextColor"
    nextTypeCode = ECT_UNKNOWN
  }
})

g_clan_type.getTypeByCode <- function getTypeByCode(code) {
  return enumsGetCachedType("code", code, g_clan_type_cache.byCode,
                                       g_clan_type, g_clan_type.UNKNOWN)
}

g_clan_type.getTypeByName <- function getTypeByName(typeName) {
  let code = string_to_clan_type(typeName)
  return this.getTypeByCode(code)
}

g_clan_type.isUpgradeAllowed <- function isUpgradeAllowed(oldType, newType) {
  return clan_is_upgrade_allowed(oldType.code, newType.code)
}

g_clan_type.getUpgradeCost <- function getUpgradeCost(oldType, newType) {
  let blk = get_warpoints_blk()
  let cost = Cost()
  if (!clan_get_admin_editor_mode()) {
    cost.gold = blk?[clan_get_upgrade_gold_cost_param_name(oldType.code, newType.code)] ?? 0
    cost.wp = blk?[clan_get_upgrade_wp_cost_param_name(oldType.code, newType.code)] ?? 0
  }
  return cost
}

return {
  g_clan_type
}