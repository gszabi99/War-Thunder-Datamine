local { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")

const timeToShowAll = 500.0

class gui_bhv.CreditsScroll
{
  function onTimer(obj, dt)
  {
    local curOffs = obj.cur_slide_offs.tofloat()

    local pos = obj.getPos()
    local size = obj.getSize()
    local parentSize = obj.getParent().getSize()
    local speedCreditsScroll = (size[1] / parentSize[1] ) / timeToShowAll

    if (pos[1]+size[1] < 0)
    {
      curOffs = -(0.9*parentSize[1]).tointeger()
      if (obj?.inited == "yes")
      {
        ::on_credits_finish()
        return
      }
      else
        obj.inited="yes"
    } else
      curOffs += dt * parentSize[1] * speedCreditsScroll //* 720 / parentSize[1] / 0.9
    obj.cur_slide_offs = ::format("%f", curOffs)
    obj.top = (-curOffs).tointeger().tostring()
  }
/*
  function onMouseWheel(obj, mx, my, is_up, buttons)
  {
    ::speedCreditsScroll *= is_up ? 0.7 : 1.5
    if (::speedCreditsScroll<0.016)
      ::speedCreditsScroll = 0.016
    if (::speedCreditsScroll>1.5)
      ::speedCreditsScroll = 1.5
    return ::RETCODE_NOTHING
  }
*/
  eventMask = ::EV_TIMER //| ::EV_MOUSE_WHEEL
  //eventMask = ::EV_TIMER

}

::on_credits_finish <- function on_credits_finish(canceled = false)
{
  if (!canceled)
    ::req_unlock_by_client("view_credits", false)
  topMenuHandler.value?.onTopMenuMain.call(topMenuHandler.value, null)
}
