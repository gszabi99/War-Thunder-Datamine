massTransp {
  id:t='crews_anim_<<countryIdx>>'
  type:t='slotbar'
  <<#needSkipAnim>>
  _transp-timer:t='1'
  <</needSkipAnim>>

  CrewsNest {
    id:t='crew_nest_<<countryIdx>>'

    slotsHeader {
      id:t='hdr_block'
      display:t='hide'

      img{
        id:t='hdr_image'
        background-image:t='<<#countryImage>><<countryImage>><</countryImage>><<^countryImage>>#ui/gameuiskin#country_0.svg<</countryImage>>'
      }
    }

    slotsScrollDiv {
      height:t='1@slotbarHeight -1@slotbar_top_shade +2@slotbarInvisPad' // @slotbarInvisPad here is to exclude overflow-y:hidden troubles (in respawn)
      pos:t='0, 1@slotbar_top_shade -1@slotbarInvisPad'; position:t='relative'
      input-transparent:t='yes'
      overflow-x:t='auto'

      slotbarTable {
        id:t='airs_table_<<countryIdx>>'
        pos:t='0, 1@slotbarInvisPad'
        position:t='relative'
        behaviour:t='<<#slotbarBehavior>><<slotbarBehavior>><</slotbarBehavior>><<^slotbarBehavior>>ActivateSelect<</slotbarBehavior>>'
        navigatorShortcuts:t='yes'
        activateChoosenItemByShortcut:t='yes'
        alwaysShowBorder:t='<<alwaysShowBorder>>'

        on_select:t = 'onSlotbarSelect'
        _on_activate:t='onSlotbarActivate'
        _on_r_click:t='onSlotbarActivate'
        _on_dbl_click:t = 'onSlotbarDblClick'

        on_pushed:t='::gcb.delayedTooltipListPush'
        on_hold_start:t='::gcb.delayedTooltipListHoldStart'
        on_hold_stop:t='::gcb.delayedTooltipListHoldStop'
      }
    }
  }
}
