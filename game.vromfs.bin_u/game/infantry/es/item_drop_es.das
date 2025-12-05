require ecs
require DagorSystem


[es(on_appear, tag=server)]
def drop_item_created_es(evt : Event; var transform : float3x4; dropTm : float3x4; item__alreadyLooted : bool)
  if item__alreadyLooted
    transform = transform * dropTm
