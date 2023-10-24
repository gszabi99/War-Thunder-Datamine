actionBar {
  id:t='action_bar'
  css-hier-invalidate:t='yes'
  pos:t='-w/2, 0'
  position:t='relative'
  behaviour:t='Timer'
  timer_handler_func:t='onUpdate'
  timer_interval_msec:t='300'

  <<#items>>
    <<>items>>
  <</items>>
}
