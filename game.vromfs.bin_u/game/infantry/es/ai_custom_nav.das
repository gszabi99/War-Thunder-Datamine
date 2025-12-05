require ecs
require %game.events
require DngWalkerai


[cpp_event(broadcast)]
struct CmdNavMeshTileRemoved
  tileId : int
  tileX : int
  tileY : int
  tileLayer : int


[es(tag=server)]
def custom_nav_tile_removed_es(evt : CmdNavMeshTileRemoved)
  query() <| $ [es] (var walker_agent : EntityAgent&)
    if walker_agent.customNav != null
      walker_agent_nav_invalidateTile(walker_agent, uint(evt.tileId), evt.tileX, evt.tileY, evt.tileLayer)

[es(tag=server, no_order)]
def custom_nav_refresh_es(info : ParallelUpdateFrameDelayed;
                          var walker_agent : EntityAgent&)
  if walker_agent.customNav != null
    walker_agent_nav_restoreTiles(walker_agent)
