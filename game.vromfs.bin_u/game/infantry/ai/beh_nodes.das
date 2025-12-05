options always_export_initializer = true
require ecs
require app
require BehNodes
require DagorDataBlock
require DagorConsole
require DagorRandom
require DagorDebug3D


def make_log_msg(owner; eid : EntityId; msg : string; paramName : string)
  if empty(paramName)
    return "{eid}: {msg}"
  let paramId = owner.blackBoard |> datablock_find_param(paramName)
  if paramId < 0
    return "{eid}: {msg} = <not found '{paramName}>"
  let paramType = owner.blackBoard |> datablock_getParamType(uint(paramId))
  if paramType == int(DataBlockParamType.TYPE_STRING)
    return "{eid}: {msg} = {owner.blackBoard |> datablock_getStr(paramId)}"
  elif paramType == int(DataBlockParamType.TYPE_INT)
    return "{eid}: {msg} = {owner.blackBoard |> datablock_getInt(paramId)}"
  elif paramType == int(DataBlockParamType.TYPE_REAL)
    return "{eid}: {msg} = {owner.blackBoard |> datablock_getReal(paramId)}"
  elif paramType == int(DataBlockParamType.TYPE_POINT3)
    return "{eid}: {msg} = {owner.blackBoard |> datablock_getPoint3(paramId)}"
  return "{eid}: {msg} = <unsuppoted type '{paramType}' of param '{paramName}'>"

[beh_node(name="log")]
class Log : BehNodeAdapter
  msg : string = "msg"
  paramName : string

  def override loadFromBlk(var data : DataBlock) : void
    msg = datablock_getStr(data, "msg", msg)
    paramName = datablock_getStr(data, "paramName", "")

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    print(make_log_msg(owner, eid, msg, paramName))
    return EBehResult.ER_SUCCESS

[beh_node(name="visualLog")]
class VisualLog : Log

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    visual_log(make_log_msg(owner, eid, msg, paramName))
    return EBehResult.ER_SUCCESS



















[beh_node(name="getTime")]
class GetTime : BehNodeAdapter
  toParam : int = -1
  addRange : float2 = float2(0.0)

  def override loadFromBlk(var data : DataBlock) : void
    toParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "to", ""), 0.0)
    addRange = datablock_getPoint2(data, "addRange", float2(0.0))

  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(toParam, float(get_sync_time() + rnd_float(addRange.x, addRange.y)))
    return EBehResult.ER_SUCCESS

[beh_node(name="checkAtTime")]
class CheckAtTime : BehNodeAdapter
  timeParam : int = -1
  timeRange : float2 = float2(0.0, 1.0)
  lessThan : bool = false
  moreThan : bool = false

  def override loadFromBlk(var data : DataBlock) : void
    timeParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "timeParam", ""), 0.0)
    timeRange = datablock_getPoint2(data, "range", timeRange)
    lessThan = datablock_getBool(data, "lessThan", lessThan)
    moreThan = datablock_getBool(data, "moreThan", moreThan)

  def override update(dt : float) : EBehResult
    let curTime = float(get_sync_time())
    let atTime = owner.blackBoard |> datablock_getReal(timeParam)
    if lessThan
      return curTime < atTime ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    if moreThan
      return curTime > atTime ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED
    return (curTime >= atTime + timeRange.x && curTime <= atTime + timeRange.y) ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="destroyEntity")]
class DestroyEntity : BehNodeAdapter

  def override update(dt : float) : EBehResult
    destroyEntity(beh_tree_eid(owner))
    return EBehResult.ER_SUCCESS















[beh_node(name="failedChance")]
class FailedChance : BehNodeAdapter
  chance : float = 0f
  chanceParam : string
  @hidden chanceParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    chance = data |> datablock_getReal("chance", chance)
    data |> load_optional_ecs_param("chanceParam", chanceParam, chanceParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let currentChance = chanceParamHash != 0u ? get_float(eid, chanceParam, chanceParamHash) ?? chance : chance
    return gfrnd() < currentChance ? EBehResult.ER_FAILED : EBehResult.ER_SUCCESS


[beh_node(name="successChance")]
class SuccessChance : BehNodeAdapter
  chance : float = 0f
  chanceParam : string
  @hidden chanceParamHash : uint

  def override loadFromBlk(var data : DataBlock)
    chance = data |> datablock_getReal("chance", chance)
    data |> load_optional_ecs_param("chanceParam", chanceParam, chanceParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    let currentChance = chanceParamHash != 0u ? get_float(eid, chanceParam, chanceParamHash) ?? chance : chance
    return gfrnd() < currentChance ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="debugBlink")]
class DebugBlink : BehNodeAdapter
  duration : int = 1000
  color : E3DCOLOR = E3DCOLOR(0xffffffff)
  posParam : string
  eidParam : string
  @hidden posParamHash : uint
  @hidden eidParamHash : uint

  def override loadFromBlk(var data : DataBlock) : void
    duration = data |> datablock_getInt("duration", duration)
    color = data |> datablock_getE3dcolor("color", color)
    data |> load_optional_ecs_param("posParam", posParam, posParamHash)
    data |> load_optional_ecs_param("eidParam", eidParam, eidParamHash)

  def override update(dt : float) : EBehResult
    let eid = beh_tree_eid(owner)
    var pos : float3
    if posParamHash != 0u
      pos = get_Point3(eid, posParam, posParamHash) ?? float3()
    if eidParamHash != 0u
      let targetEid = get_Eid(eid, eidParam, eidParamHash) ?? INVALID_ENTITY_ID
      query(targetEid) <| $ [es] (transform : float3x4)
        pos = transform[3]
    draw_debug_sphere_buffered(pos, 1, color, duration)
    return EBehResult.ER_SUCCESS


[beh_node(name="isDoor")]
class IsDoor : BehNodeAdapter
  targetParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    let param = datablock_getStr(data, "param", "")
    if !empty(param)
      targetParam = owner.blackBoard |> get_or_create(param, targetParam)

  def override update(dt : float) : EBehResult
    let eid = owner.blackBoard |> datablock_getInt(targetParam)
    var result = EBehResult.ER_FAILED
    query(EntityId(uint(eid))) <| $ [es] (isDoor : bool)
      if isDoor
        result = EBehResult.ER_SUCCESS
    return result


[beh_node(name="setTransformPosFromEntity")]
class SetTransformPosFromEntityNode : BehNodeAdapter
  posParam : int = -1
  eidParam : int = -1
  localParam : int = -1

  def override loadFromBlk(var data : DataBlock) : void
    posParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "to", ""), float3())
    eidParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "from", ""), 0)
    if datablock_find_param(data, "local") >= 0
      localParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "local", ""), float3())

  def override update(dt : float) : EBehResult
    let eid = owner.blackBoard |> datablock_getInt(eidParam)
    var result = EBehResult.ER_FAILED
    query(EntityId(uint(eid))) <| $ [es] (transform : float3x4)
      var pos = transform[3]
      if localParam >= 0
        let localPos = owner.blackBoard |> datablock_getPoint3(localParam)
        pos = transform * localPos
      owner.blackBoard |> set(posParam, transform[3])
      result = EBehResult.ER_SUCCESS
    return result

[beh_node(name="isZeroPoint3")]
class IsZeroPoint3 : BehNodeAdapter
  varParam : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    varParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "var", ""), float3())
  def override update(dt : float) : EBehResult
    let pos = owner.blackBoard |> datablock_getPoint3(varParam)
    return pos == float3() ? EBehResult.ER_SUCCESS : EBehResult.ER_FAILED

[beh_node(name="zeroPoint3")]
class ZeroPoint3 : BehNodeAdapter
  varParam : int = -1
  def override loadFromBlk(var data : DataBlock) : void
    varParam = owner.blackBoard |> get_or_create(datablock_getStr(data, "var", ""), float3())
  def override update(dt : float) : EBehResult
    owner.blackBoard |> set(varParam, float3())
    return EBehResult.ER_SUCCESS
