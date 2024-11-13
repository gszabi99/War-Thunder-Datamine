from "%scripts/dagui_natives.nut" import clan_get_decorators_block_name
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { get_warpoints_blk } = require("blkGetters")

class ClanTagDecorator {
  id = null
  start = null
  end = null
  free = false

  constructor(decoratorString, freeChange) {
    let halfLength = (0.5 * decoratorString.len()).tointeger()
    this.id = decoratorString
    this.start = decoratorString.slice(0, halfLength)
    this.end = decoratorString.slice(halfLength)
    this.free = freeChange
  }

  function checkTagText(tagText) {
    if (tagText.indexof(this.start) != 0 || tagText.len() < this.end.len())
      return false
    return tagText.slice(-this.end.len()) == this.end
  }
}

::g_clan_tag_decorator <- {


  function getDecorators(args) {
    let decoratorsList = []

    if ("clanType" in args)
      decoratorsList.extend(this.getDecoratorsForClanType(args.clanType))

    if ("rewardsList" in args)
      decoratorsList.extend(this.getDecoratorsForClanDuelRewards(args.rewardsList))

    return decoratorsList
  }


  function getDecoratorsForClanType(clanType) {
    let blk = get_warpoints_blk()
    let block = blk?[clan_get_decorators_block_name(clanType.code)]

    return this.getDecoratorsInternal(block)
  }


  function getDecoratorsForClanDuelRewards(rewardsList) {
    local blk = get_warpoints_blk()
    let result = []

    if (!blk?.regaliaTagDecorators)
      return result

    blk = blk.regaliaTagDecorators

    let decoratorLists = []
    foreach (reward in rewardsList)
      decoratorLists.append(this.getDecoratorsInternal(blk?[reward], true))
    decoratorLists.sort(@(a, b) b.len() <=> a.len())

    foreach (list in decoratorLists)
      foreach (decorator in list)
        if (!u.search(result, @(d) d.id == decorator.id))
          result.append(decorator)

    return result
  }


  /**
   * Return array of ClanTagDecorator's
   * @deocratorsBlk - datablock in format:
   * {
   *   decor:t='<start><end>'; //start and end have equal length
   *
   *   ...
   * }
   */
  function getDecoratorsInternal(decoratorsBlk, free = false) {
    let decorators = []

    if (decoratorsBlk != null)
      foreach (decoratorString in decoratorsBlk % "decor")
        decorators.append(ClanTagDecorator(decoratorString, free))

    return decorators
  }
}
