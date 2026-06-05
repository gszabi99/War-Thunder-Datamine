options no_aot
require ecs
require DagorConsole
require RendInst
require DagorDataBlock
require app


def console_print_debug(msg : string)
  console_print(msg)
  print(msg)


[console_cmd(name="doors.list_no_destr")]
def list_no_destr_doors_cmd(with_positions : bool = false)
  var infantryDmgRIs : table<string>
  datablock_load_cached("config/_rendinst_infantry_dmg.blk") <| $(dmgBlk : DataBlock)
    for i in 0u..dmgBlk.blockCount
      let child = dmgBlk |> datablock_get_block(i)
      if child != null
        insert(infantryDmgRIs, child.blockName)

  if empty(infantryDmgRIs)
    console_print_debug("Failed to load config/_rendinst_infantry_dmg.blk or it is empty")
    return

  var doorRiNames : table<string>
  var doorRiInstances : array<string>

  query() <| $ [es(REQUIRE=isDoor)] (ri_extra : RiExtraComponent; transform : float3x4)
    if !ri_extra.valid
      return
    let riType = handle_to_ri_type(ri_extra.handle)
    let riName = riex_getRIGenExtraName(riType)
    if riName == ""
      return
    if !key_exists(infantryDmgRIs, riName)
      insert(doorRiNames, riName)
      if with_positions
        let pos = transform[3]
        push(doorRiInstances, "{riName}  ({pos.x:.1f}, {pos.y:.1f}, {pos.z:.1f})")

  var sortedNames : array<string>
  for name in keys(doorRiNames)
    push(sortedNames, name)
  sort(sortedNames)
  sort(doorRiInstances)

  console_print_debug("Doors WITHOUT destruction ({length(sortedNames)} unique):")
  if with_positions
    for entry in doorRiInstances
      console_print_debug("  - {entry}")
  else
    for name in sortedNames
      console_print_debug("  - {name}")
  shrink_heap_memory()
