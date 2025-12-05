require ecs
require app
require CollRes
require Covers
require math
require DagorMath

require %appGame.infantry.ai.covers_common

[es(tag=server, REQUIRE=player, before=(beh_tree_update_es))]
def update_ai_covers(act : UpdateStageInfoAct;
                     possessed : EntityId;
                     covers__coversCheckInterval : float;
                     var covers__nextCoversCheckTime : float&)
  if !possessed || act.curTime < covers__nextCoversCheckTime
    return

  covers__nextCoversCheckTime = act.curTime + covers__coversCheckInterval

  query() <| $ [es] (var covers : CoversComponent&)
    query(possessed) <| $ [es] (transform : float3x4;
                                collres : CollisionResource;
                                var cover_updater__heldCovers : IPoint2List&)
      var box = collres.vFullBBox

      box.bmin.xyz += transform[3]
      box.bmax.xyz += transform[3]

      reset_covers(covers, cover_updater__heldCovers)

      covers_box_cull(covers, box) <| $(id : int;
                                        tm : mat44f#)
        let ptA = (box.bmin.xyz + box.bmax.xyz) * 0.5
        let ptB = transform[3]

        if isPointInCover(covers, tm, ptA) || isPointInCover(covers, tm, ptB)
          fill_cover(id, covers, cover_updater__heldCovers)