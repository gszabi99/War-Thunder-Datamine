module covers_common shared

require ecs
require Covers

def reset_covers(eid : EntityId)
  query() <| $ [es] (var covers : CoversComponent&)
    query(eid) <| $ [es] (var cover_updater__heldCovers : IPoint2List&)
      reset_covers(covers, cover_updater__heldCovers)

def reset_covers(var covers : CoversComponent&;
                 var cover_updater__heldCovers : IPoint2List&)
  for coverId in cover_updater__heldCovers
    covers |> releaseSlot(coverId.x, coverId.y)
  clear(cover_updater__heldCovers)


def fill_cover(id : int;
               var covers : CoversComponent&;
               var cover_updater__heldCovers : IPoint2List&)
  for slotId in range(covers.coverDescs[id].numSlots)
    push(cover_updater__heldCovers, int2(id, slotId))
    covers |> occupySlot(id, slotId)
