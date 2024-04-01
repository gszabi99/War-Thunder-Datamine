craftTreeScrollDiv {
  id:t='craft_tree'
  position:t='relative'
  left:t='0.5pw-0.5w'
  flow:t='vertical'
  <<#itemsSize>>itemsSize:t='<<itemsSize>>'<</itemsSize>>
  tdiv {
    id:t='craft_header'
    include "%gui/items/craftTreeHeader.tpl"
  }

  craftBranchBody {
    id:t='craft_body'
    size:t='<<bodyWidth>>, <<bodyHeight>>'
    flow:t='h-flow'
    total-input-transparent:t='yes'

    behaviour:t='posNavigator'
    navigatorShortcuts:t='yes'
    moveX:t='linear'
    moveY:t='closest'

    on_activate:t='onMainAction'
    on_pushed:t='::gcb.delayedTooltipListPush'
    on_hold_start:t='::gcb.delayedTooltipListHoldStart'
    on_hold_stop:t='::gcb.delayedTooltipListHoldStop'

    include "%gui/items/craftTreeBody.tpl"
  }
}

timer
{
  id:t='update_timer'
  timer_handler_func:t='onTimer'
  timer_interval_msec:t='1000'
}
