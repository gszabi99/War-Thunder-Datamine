animated_wait_icon
{
  id:t='wait_animation'
  position:t='relative'
  pos:t='50%pw-50%w, 50%ph - 50%h'
  background-rotation:t='0'
  display:t='hide'
}

textAreaCentered {
  id:t='no_leaderboads_text'
  position:t='absolute'
  pos:t='50%pw-50%w, 50%ph - 50%h'
  text:t='#mainmenu/no_leaderboards'
  display:t='hide'
}

table {
  id:t='lb_table'
  size:t='pw, ph'
  useNavigatorOrInteractiveCells:t='yes'
  class:t='lbTable'
  text-valign:t='center'
  text-halign:t='center'
  navigatorShortcuts:t='yes'
  selfFocusBorder:t='yes'
  on_click:t='onRowSelect'
  on_dbl_click:t='onRowDblClick'
  on_r_click:t='onRowRClick'
  overflow-y:t='auto'
  display:t='hide'
}
