::lights <- []

::light_lerp <- function light_lerp(t1, t2, v)
{
  return t1 + (t2 - t1) * v
}

::lights_inited <- false

::on_enter_hangar <- function on_enter_hangar()
{
  if (::lights_inited)
    return

  ::lights_inited = true
  local blk = ::DataBlock( "levels/hangar_winter_airfield_lights.blk" )
  local list = blk?.lights ?? ::DataBlock()
  for ( local i = 0 ; i < list.blockCount() ; ++i )
  {
    local src = list.getBlock( i )

    local light =
    {
      id = 0
      pos = src.pos
      pos_range = src.posdelta ? src.posdelta : 0
      rad = src.radius
      rad_range = src.radiusdelta ? src.radiusdelta : 0
      col0 = src.color
      col1 = src.colorto ? src.colorto : src.color
      pow0 = src.powerfrom ? src.powerfrom : 1
      pow1 = src.powerto ? src.powerto : 1
    }

    light.id = ::add_light(0, light.pos, light.col0, light.rad)
    lights.append(light)
  }
}

::on_leave_hangar <- function on_leave_hangar()
{
  if (! ::lights_inited)
    return

  ::lights_inited = false
  local cnt = ::lights.len()
  for ( local i = 0 ; i < cnt ; ++i )
  {
    local l = ::lights[i]
    ::destroy_light( l.id )
  }
  ::lights.clear()
}

::update_hangar_timer <- 0.0
::on_update_hangar <- function on_update_hangar( dt )
{
  if (! ::lights_inited)
    on_enter_hangar()

  ::update_hangar_timer -= dt
  if (::update_hangar_timer > 0)
    return
  ::update_hangar_timer = ::update_hangar_timer % 0.1 + 0.1

  foreach(l in ::lights)
  {
    local col = light_lerp( l.col0, l.col1, ::math.frnd() )
    col *= light_lerp( l.pow0, l.pow1, ::math.frnd() )

    local rad = l.rad + l.rad_range * ::math.frnd()

    local dir = ::Point3(::math.frnd(), ::math.frnd(), ::math.frnd())
    dir.normalize()
    local pos = l.pos + dir * l.pos_range * ::math.frnd()

    ::set_light_col( l.id, col )
    ::set_light_pos( l.id, pos )
    ::set_light_radius( l.id, rad )
  }
}