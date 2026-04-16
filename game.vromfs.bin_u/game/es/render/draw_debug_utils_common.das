module draw_debug_utils_common shared
require ecs
require DagorMath

[generic]
def draw_debug_text_mark_buffered(pos : float3x4; msg : string; duration : int; color : E3DCOLOR = E3DCOLOR(0xffffffff))
  draw_debug_text_mark_buffered(pos[3], msg, duration, color)

[generic]
def draw_debug_text_mark_buffered(pos : float3; msg : string; duration : int; color : E3DCOLOR = E3DCOLOR(0xffffffff))
  createEntity("buffered_text_mark") <| $(init)
    init |> set("buffered_text_mark__pos", pos)
    init |> set("buffered_text_mark__msg", msg)
    init |> set("buffered_text_mark__left", duration)
    init |> set("buffered_text_mark__color", color)
