::getNearestSelectableChildIndex <- function getNearestSelectableChildIndex(listObj, curIndex, way)
{
  if (!check_obj(listObj))
    return curIndex

  local step = (way >= 0)? 1 : -1
  local breakAt = (way >= 0)? listObj.childrenCount() : -1
  for (local i = curIndex + step; i != breakAt; i += step)
  {
    local iObj = listObj.getChild(i)
    if (!check_obj(iObj))
      continue
    if (!iObj.isVisible() || !iObj.isEnabled() || iObj?.inactive=="yes")
      continue
    return i
  }
  return curIndex
}

::is_obj_have_active_childs <- function is_obj_have_active_childs(obj)
{
  for(local i = 0; i < obj.childrenCount(); i++)
  {
    local iObj = obj.getChild(i)
    if (iObj.isVisible() && iObj.isEnabled() && iObj?.inactive!="yes")
      return true
  }
  return false
}

if (!("play_gui_sound" in getroottable())) //!!FIX ME: remove this function and use direct guiScene sound when it appear on all platforms
  ::play_gui_sound <- function(soundName)
  {
    ::get_gui_scene().playSound(soundName)
  }