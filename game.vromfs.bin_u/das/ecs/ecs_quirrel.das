module ecs_quirrel shared public

require ecs public
require DagorMath public
require DagorQuirrel public
require daslib/quirrel_boost public
require daslib/constant_expression


[constant_expression(baseTypeName)]
def pop_class_value_slow(var vm : SQVM?; idx : int64; baseTypeName : string; cb : block<(res : auto(T)#) : void>)
  var actualType : AbstractStaticClassData?
  if sq_gettypetag(vm, idx, unsafe(reinterpret<void ??> unsafe(addr(actualType)))) >= 0l
    var correctType = false
    var t = actualType
    while t != null
      if baseTypeName == t.className
        correctType = true
        break
      t = t.baseClass

    if correctType
      var res : void?
      if sq_getinstanceup(vm, idx, unsafe(addr(res)), null) >= 0l
        cb |> invoke(**unsafe(reinterpret<T ??> res))
        return true
    else
      to_log(LOG_ERROR, "Type mismatch: expected {baseTypeName}, got {actualType.className}")
  else
    to_log(LOG_ERROR, "Unable to read instance type tag (sq_gettypetag)")
  return false

[constant_expression(baseTypeName)]
def pop_class_value_rw_slow(var vm : SQVM?; idx : int64; baseTypeName : string; cb : block<(var res : auto(T)#) : void>)
  var actualType : AbstractStaticClassData?
  if sq_gettypetag(vm, idx, unsafe(reinterpret<void ??> unsafe(addr(actualType)))) >= 0l
    var correctType = false
    var t = actualType
    while t != null
      if baseTypeName == t.className
        correctType = true
        break
      t = t.baseClass

    if correctType
      var res : void?
      if sq_getinstanceup(vm, idx, unsafe(addr(res)), null) >= 0l
        cb |> invoke(**unsafe(reinterpret<T# ??> res))
        return true
    else
      to_log(LOG_ERROR, "Type mismatch: expected {baseTypeName}, got {actualType.className}")
  else
    to_log(LOG_ERROR, "Unable to read instance type tag (sq_gettypetag)")
  return false


def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : EntityId#) : void>)
  return popValue(vm, idx) <| $(res : uint)
    cb |> invoke(EntityId(res))


def pushValue(var vm : SQVM?; val : EntityId) { pushValue(vm, uint(val)); }

// generated block

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Object#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Object?)
    cb |> invoke(unsafe(reinterpret<Object#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Object#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Object?)
    cb |> invoke(unsafe(reinterpret<Object#> * val))
  return true

def pushValue(var vm : SQVM?; val : Object const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Object implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Array#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Array?)
    cb |> invoke(unsafe(reinterpret<Array#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Array#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Array?)
    cb |> invoke(unsafe(reinterpret<Array#> * val))
  return true

def pushValue(var vm : SQVM?; val : Array const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Array implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : StringList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : StringList?)
    cb |> invoke(unsafe(reinterpret<StringList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : StringList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : StringList?)
    cb |> invoke(unsafe(reinterpret<StringList#> * val))
  return true

def pushValue(var vm : SQVM?; val : StringList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : StringList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : FloatList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : FloatList?)
    cb |> invoke(unsafe(reinterpret<FloatList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : FloatList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : FloatList?)
    cb |> invoke(unsafe(reinterpret<FloatList#> * val))
  return true

def pushValue(var vm : SQVM?; val : FloatList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : FloatList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : IntList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IntList?)
    cb |> invoke(unsafe(reinterpret<IntList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : IntList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IntList?)
    cb |> invoke(unsafe(reinterpret<IntList#> * val))
  return true

def pushValue(var vm : SQVM?; val : IntList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : IntList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Int8List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int8List?)
    cb |> invoke(unsafe(reinterpret<Int8List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Int8List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int8List?)
    cb |> invoke(unsafe(reinterpret<Int8List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Int8List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Int8List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Int16List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int16List?)
    cb |> invoke(unsafe(reinterpret<Int16List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Int16List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int16List?)
    cb |> invoke(unsafe(reinterpret<Int16List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Int16List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Int16List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Int64List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int64List?)
    cb |> invoke(unsafe(reinterpret<Int64List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Int64List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Int64List?)
    cb |> invoke(unsafe(reinterpret<Int64List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Int64List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Int64List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : UInt8List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt8List?)
    cb |> invoke(unsafe(reinterpret<UInt8List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : UInt8List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt8List?)
    cb |> invoke(unsafe(reinterpret<UInt8List#> * val))
  return true

def pushValue(var vm : SQVM?; val : UInt8List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : UInt8List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : UInt16List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt16List?)
    cb |> invoke(unsafe(reinterpret<UInt16List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : UInt16List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt16List?)
    cb |> invoke(unsafe(reinterpret<UInt16List#> * val))
  return true

def pushValue(var vm : SQVM?; val : UInt16List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : UInt16List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : UInt32List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt32List?)
    cb |> invoke(unsafe(reinterpret<UInt32List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : UInt32List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt32List?)
    cb |> invoke(unsafe(reinterpret<UInt32List#> * val))
  return true

def pushValue(var vm : SQVM?; val : UInt32List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : UInt32List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : UInt64List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt64List?)
    cb |> invoke(unsafe(reinterpret<UInt64List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : UInt64List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : UInt64List?)
    cb |> invoke(unsafe(reinterpret<UInt64List#> * val))
  return true

def pushValue(var vm : SQVM?; val : UInt64List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : UInt64List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : EidList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : EidList?)
    cb |> invoke(unsafe(reinterpret<EidList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : EidList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : EidList?)
    cb |> invoke(unsafe(reinterpret<EidList#> * val))
  return true

def pushValue(var vm : SQVM?; val : EidList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : EidList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Point2List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point2List?)
    cb |> invoke(unsafe(reinterpret<Point2List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Point2List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point2List?)
    cb |> invoke(unsafe(reinterpret<Point2List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Point2List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Point2List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Point3List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point3List?)
    cb |> invoke(unsafe(reinterpret<Point3List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Point3List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point3List?)
    cb |> invoke(unsafe(reinterpret<Point3List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Point3List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Point3List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Point4List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point4List?)
    cb |> invoke(unsafe(reinterpret<Point4List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : Point4List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Point4List?)
    cb |> invoke(unsafe(reinterpret<Point4List#> * val))
  return true

def pushValue(var vm : SQVM?; val : Point4List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Point4List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : IPoint2List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IPoint2List?)
    cb |> invoke(unsafe(reinterpret<IPoint2List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : IPoint2List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IPoint2List?)
    cb |> invoke(unsafe(reinterpret<IPoint2List#> * val))
  return true

def pushValue(var vm : SQVM?; val : IPoint2List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : IPoint2List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : IPoint3List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IPoint3List?)
    cb |> invoke(unsafe(reinterpret<IPoint3List#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : IPoint3List#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : IPoint3List?)
    cb |> invoke(unsafe(reinterpret<IPoint3List#> * val))
  return true

def pushValue(var vm : SQVM?; val : IPoint3List const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : IPoint3List implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : BoolList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BoolList?)
    cb |> invoke(unsafe(reinterpret<BoolList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : BoolList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BoolList?)
    cb |> invoke(unsafe(reinterpret<BoolList#> * val))
  return true

def pushValue(var vm : SQVM?; val : BoolList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : BoolList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : TMatrixList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : TMatrixList?)
    cb |> invoke(unsafe(reinterpret<TMatrixList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : TMatrixList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : TMatrixList?)
    cb |> invoke(unsafe(reinterpret<TMatrixList#> * val))
  return true

def pushValue(var vm : SQVM?; val : TMatrixList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : TMatrixList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : ColorList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : ColorList?)
    cb |> invoke(unsafe(reinterpret<ColorList#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : ColorList#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : ColorList?)
    cb |> invoke(unsafe(reinterpret<ColorList#> * val))
  return true

def pushValue(var vm : SQVM?; val : ColorList const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : ColorList implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : float3x4#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : float3x4?)
    cb |> invoke(unsafe(reinterpret<float3x4#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : float3x4#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : float3x4?)
    cb |> invoke(unsafe(reinterpret<float3x4#> * val))
  return true

def pushValue(var vm : SQVM?; val : float3x4 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : float3x4 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : BSphere3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BSphere3?)
    cb |> invoke(unsafe(reinterpret<BSphere3#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : BSphere3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BSphere3?)
    cb |> invoke(unsafe(reinterpret<BSphere3#> * val))
  return true

def pushValue(var vm : SQVM?; val : BSphere3 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : BSphere3 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : BBox3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BBox3?)
    cb |> invoke(unsafe(reinterpret<BBox3#> * val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : BBox3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : BBox3?)
    cb |> invoke(unsafe(reinterpret<BBox3#> * val))
  return true

def pushValue(var vm : SQVM?; val : BBox3 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : BBox3 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : E3DCOLOR#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : E3DCOLOR?)
    cb |> invoke(unsafe(reinterpret<E3DCOLOR#> * val))
  return true

def pushValue(var vm : SQVM?; val : E3DCOLOR const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : E3DCOLOR implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Color3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Color3?)
    cb |> invoke(unsafe(reinterpret<Color3#> * val))
  return true

def pushValue(var vm : SQVM?; val : Color3 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Color3 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : Color4#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : Color4?)
    cb |> invoke(unsafe(reinterpret<Color4#> * val))
  return true

def pushValue(var vm : SQVM?; val : Color4 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : Color4 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : quat#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : quat?)
    cb |> invoke(unsafe(reinterpret<quat#> * val))
  return true

def pushValue(var vm : SQVM?; val : quat const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : quat implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : float2#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : float2?)
    cb |> invoke(unsafe(reinterpret<float2#> * val))
  return true

def pushValue(var vm : SQVM?; val : float2 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : float2 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : float3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : float3?)
    cb |> invoke(unsafe(reinterpret<float3#> * val))
  return true

def pushValue(var vm : SQVM?; val : float3 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : float3 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : float4#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : float4?)
    cb |> invoke(unsafe(reinterpret<float4#> * val))
  return true

def pushValue(var vm : SQVM?; val : float4 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : float4 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : int2#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : int2?)
    cb |> invoke(unsafe(reinterpret<int2#> * val))
  return true

def pushValue(var vm : SQVM?; val : int2 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : int2 implicit) : void
  PushInstanceCopy(vm, val)

def popValue(var vm : SQVM?; idx : int64; cb : block<(res : int3#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : int3?)
    cb |> invoke(unsafe(reinterpret<int3#> * val))
  return true

def pushValue(var vm : SQVM?; val : int3 const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : int3 implicit) : void
  PushInstanceCopy(vm, val)


/*
[init]
def gen()

  let rwTypes <- [{auto[]
    "Object";
    "Array";
    "StringList";
    "FloatList";
    "IntList";
    "Int8List";
    "Int16List";
    "Int64List";
    "UInt8List";
    "UInt16List";
    "UInt32List";
    "UInt64List";
    "EidList";
    "Point2List";
    "Point3List";
    "Point4List";
    "IPoint2List";
    "IPoint3List";
    "BoolList";
    "TMatrixList";
    "ColorList";
    "float3x4";
    "BSphere3";
    "BBox3"
  }]

  let valueTypes <- [{auto[]
    "E3DCOLOR";
    "Color3";
    "Color4";
    "quat";
    "float2";
    "float3";
    "float4";
    "int2";
    "int3"
    //"int4"
  }]

  for typ in rwTypes
    print("
def popValue(var vm : SQVM?; idx : int64; cb : block<(res : {typ}#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : {typ}?)
    cb |> invoke(unsafe(reinterpret<{typ}#> *val))
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : {typ}#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : {typ}?)
    cb |> invoke(unsafe(reinterpret<{typ}#> *val))
  return true

def pushValue(var vm : SQVM?; val : {typ} const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : {typ} implicit) : void
  PushInstanceCopy(vm, val)");

  for typ in valueTypes
    print("
def popValue(var vm : SQVM?; idx : int64; cb : block<(res : {typ}#) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : {typ}?)
    cb |> invoke(unsafe(reinterpret<{typ}#> *val))
  return true

def pushValue(var vm : SQVM?; val : {typ} const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : {typ} implicit) : void
  PushInstanceCopy(vm, val)");
*/

/*
[constant_expression(baseTypeName)]
def push_class_value_slow(var vm : SQVM?; baseTypeName : string; val#) : void
  var found = false
  find_AbstractStaticClassData() <| $(cls)
    if cls.className == baseTypeName
      found = true
      console_print("push obj of {cls} {val}")
      sq_pushobject(vm, unsafe(addr(ClassData<T>::classObject)))
      sq_createinstance(vm, -1l)
      sq_setinstanceup(vm, -1l, unsafe(addr(val)))
      // sq_pop(vm, 1l)
      return true
    return false
  if !found
    to_log(LOG_ERROR, "Unable to push instance with type '{baseTypeName}'")
    sq_pushnull(vm)


def popValue(var vm : SQVM?; idx : int64; cb : block<(res : auto(T)) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : T?#)
    cb |> invoke(*val)
  return true

def popValue(var vm : SQVM?; idx : int64; cb : block<(var res : auto(T)) : void>) : bool
  GetInstance(vm, idx, false) <| $(var val : T?)
    cb |> invoke(unsafe(reinterpret<T> *val))
  return true

def pushValue(var vm : SQVM?; val : auto const implicit? implicit) : void
  if val != null
    PushInstanceCopy(vm, *val)
  else
    sq_pushnull(vm)

def pushValue(var vm : SQVM?; val : auto implicit) : void
  PushInstanceCopy(vm, val)
 */