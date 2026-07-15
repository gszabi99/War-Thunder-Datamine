AimPointSelector {
  id:t='weapon_to_point_selector'
  position:t='absolute'
  interactive:t='yes'
  css-hier-invalidate:t='yes'

  tdiv {
    id:t='buttons_container'
    position:t='relative'
    flow:t='horizontal'
    interactive:t='yes'
    behaviour:t='posNavigator'
    navigatorShortcuts:t='SpaceA'
    css-hier-invalidate:t='yes'
    input-transparent:t='yes'

    <<#slots>>
      AimPointSelectorItem{
        id:t='slot_<<slotId>>'
        position:t='relative'
        margin:t='0.003@shHud, 0, 0.003@shHud, 0'
        flow:t='vertical'
        hasBullets:t='yes'
        slotId:t='<<slotId>>'
        enabled:t='no'
        on_click:t='onWeaponSlotClick'
        on_r_click:t='onWeaponRightClick'
        input-transparent:t='yes'

        label {
          id:t='label'
          width:t='pw'
          padding:t='0, 1@sf/@pf'
          position:t='relative'
          text:t=''
          background-color:t='@apsBgColor'
          text-align:t='center'

          text-shade:t='blur:24'
          text-shade-x:t='0'
          text-shade-y:t='0'
          text-shade-color:t='#AA000000'
        }
        AimPointSelectorIcon {
          background-image:t='<<#img>><<img>><</img>>'
        }
        label {
          id:t='total_count'
          position:t='absolute'
          right:t='2@sf/@pf'
          bottom:t='2@sf/@pf'
          text:t=''
          text-align:t='right'

          text-shade:t='blur:24'
          text-shade-x:t='0'
          text-shade-y:t='0'
          text-shade-color:t='#AA000000'
        }
        focus_border {}
      }
    <</slots>>
  }
}

timer{
  id:t='aim_mem_points_selector_timer'
  timer_interval_msec:t='50'
  timer_handler_func:t='onAimMemPointsSelectorTimer'
}