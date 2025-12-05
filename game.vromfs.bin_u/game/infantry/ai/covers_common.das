module covers_common shared

require ecs
require Covers
require DagorSystem

def reset_covers(eid : EntityId)
  query() <| $ [es] (var covers : CoversComponent&)
    query(eid) <| $ [es] (var cover_updater__heldCovers : IPoint2List&)
      reset_covers(covers, cover_updater__heldCovers)

def reset_covers(var covers : CoversComponent&;
                 var cover_updater__heldCovers : IPoint2List&)
  for coverId in cover_updater__heldCovers
    assume cover = covers.coverDescs[coverId.x]
    assume coverNumUsed = cover.slots[coverId.y].numUsed

    coverNumUsed -= 1

    if coverNumUsed == 0
      cover.numUsedSlots -= 1

    if coverNumUsed < 0
      logerr("coverDescs numUsed overflow")
    if cover.numUsedSlots < 0
      logerr("coverDescs numUsedSlots overflow")

  clear(cover_updater__heldCovers)


def fill_cover(id : int;
               var covers : CoversComponent&;
               var cover_updater__heldCovers : IPoint2List&)
  var slotId = 0
  for slot in covers.coverDescs[id].slots
    push(cover_updater__heldCovers, int2(id, slotId++))

    slot.numUsed += 1

    if slot.numUsed == 1
      ++covers.coverDescs[id].numUsedSlots
