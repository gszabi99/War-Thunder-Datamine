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

      table {
        id:t='airs_table_<<countryIdx>>'
        pos:t='0, 1@slotbarInvisPad'; position:t='relative'
        class:t='slotbarTable'
        total-input-transparent:t="yes"
        navigatorShortcuts:t='yes';
        behavior:t='columnNavigator'
        cur_col:t='-1'
        cur_row:t='-1'
        fixed_row:t='0'
        on_select:t = 'onSlotbarSelect';
        on_click:t = 'onSlotbarClick';
        _on_dbl_click:t = 'onSlotbarDblClick'
        on_wrap_up:t='onWrapUp';
        on_wrap_down:t='onWrapDown';
        clearOnFocusLost:t='no'
        alwaysShowBorder:t='<<alwaysShowBorder>>'
      }
    }
  }
}
