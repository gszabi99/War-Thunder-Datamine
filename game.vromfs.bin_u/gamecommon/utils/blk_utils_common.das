module blk_utils_common shared

require DagorDataBlock
require ecs
require math.base

[generic]
def datablock_to_object(data_block : DataBlock | #; var object : Object&)
  for i in 0u..data_block.paramCount
    let paramName = data_block |> datablock_get_param_name(i)
    let paramType = data_block |> datablock_getParamType(i)
    if paramType == int(DataBlockParamType.TYPE_STRING)
      object |> set(paramName, datablock_getStr(data_block, paramName, ""))
    elif paramType == int(DataBlockParamType.TYPE_INT)
      object |> set(paramName, datablock_getInt(data_block, paramName, -1))
    elif paramType == int(DataBlockParamType.TYPE_REAL)
      object |> set(paramName, datablock_getReal(data_block, paramName, -1.0))
    elif paramType == int(DataBlockParamType.TYPE_POINT2)
      object |> set(paramName, datablock_getPoint2(data_block, paramName, float2()))
    elif paramType == int(DataBlockParamType.TYPE_POINT3)
      object |> set(paramName, datablock_getPoint3(data_block, paramName, float3()))
    elif paramType == int(DataBlockParamType.TYPE_POINT4)
      object |> set(paramName, datablock_getPoint4(data_block, paramName, float4()))
    elif paramType == int(DataBlockParamType.TYPE_IPOINT2)
      object |> set(paramName, datablock_getIPoint2(data_block, paramName, int2()))
    elif paramType == int(DataBlockParamType.TYPE_IPOINT3)
      object |> set(paramName, datablock_getIPoint3(data_block, paramName, int3()))
    elif paramType == int(DataBlockParamType.TYPE_BOOL)
      object |> set(paramName, datablock_getBool(data_block, paramName, false))
    elif paramType == int(DataBlockParamType.TYPE_E3DCOLOR)
      object |> set(paramName, datablock_getE3dcolor(data_block, paramName, E3DCOLOR()))
    elif paramType == int(DataBlockParamType.TYPE_MATRIX)
      object |> set(paramName, datablock_getTm(data_block, paramName, IDENT_TM))
    elif paramType == int(DataBlockParamType.TYPE_INT64)
      object |> set(paramName, datablock_getInt64(data_block, paramName, int64(-1)))
    elif paramType == int(DataBlockParamType.TYPE_IPOINT4)
      object |> set(paramName, datablock_getIPoint4(data_block, paramName, int4()))
