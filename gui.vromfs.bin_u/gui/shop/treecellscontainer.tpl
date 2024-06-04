shopRankTable {
  id:t='rank_table_<<containerId>>'
  containerIndex:t='<<containerId>>'
  position:t='relative'
  width:t='pw'
  isCollapsed:t='no'
  overflow:t='hidden'

  behaviour:t='basicSize'
  height-base:t='100'
  height-end:t='100'
  size-func:t='cube'
  size-scale:t='screen'
  size-time:t='250'
  _size-timer:t='1'
  on_anim_finish:t='onRankAnimFinish'

  <<#hasHorizontalSeparator>>
  tdiv {
    id:t='horizontal_line'
    size:t='pw, 1@dp'
    pos:t='0, 0'
    position:t='absolute'
    background-color:t='@frameSeparatorColor'
  }
  <</hasHorizontalSeparator>>

  tdiv {
    id:t='backgrounds'
    size:t='pw, ph'
    pos:t='0, 0'
    position:t='absolute'
    display:t='show'
  }

  tdiv {
    id:t='arrows_container'
    input-transparent:t="yes"
    position:t='absolute'
    pos:t='(pw-w)/2, 0'
  }

  tdiv {
    position:t='absolute'
    id:t='cells_container'
    total-input-transparent:t='yes'
    interactive:t='no'
    isContainer:t='yes'
    height:t='ph-2'
    css-hier-invalidate:t='yes'
    pos:t='(pw-w)/2, 0'
    on_pushed:t='::gcb.delayedTooltipListPush'
    on_hold_start:t='::gcb.delayedTooltipListHoldStart'
    on_hold_stop:t='::gcb.delayedTooltipListHoldStop'
  }

  tdiv {
    id:t='fades'
    display:t='hide'
    position:t='absolute'
    input-transparent:t="yes"
    height:t='ph'
  }

  tdiv {
    id:t='collapsed_icons'
    height:t='ph'
    pos:t='0, ph-h'
    position:t='absolute'
    display:t='hide'
  }

  tdiv {
    id:t='others'
    position:t='absolute'
    size:t='0, 0'

    tdiv {
      id:t='bottom_horizontal_line'
      size:t='p.p.w, 1@dp'
      pos:t='0, p.p.h-h'
      position:t='absolute'
      background-color:t='@frameSeparatorColor'
      display:t='hide'
    }
    tdiv {
      id:t='bottom_black_line'
      size:t='pw, 1@dp'
      pos:t='0, ph-1@dp'
      position:t='absolute'
      background-color:t='@black'
    }
    shopArrow {
      id:t='shop_arrow'
      type:t='vertical'
      position:t='absolute'
      min-height:t='0.8@shop_height'
      pos:t='0.4@modArrowWidth, 1@modBlockTierNumHeight'
      size:t='1@modArrowWidth, p.p.h - 1@modBlockTierNumHeight - 4@dp'
      input-transparent:t='yes'
      shopStat:t='owned'
      isRed:t='no'
      shopArrowPlate{
        id:t='mod_arrow_plate'
        pos:t='(pw - w)/2, (p.p.p.h  - 1@modBlockTierNumHeight - 4@dp - h)/2'
        isRed:t='no'
        css-hier-invalidate:t='yes'
        img {
          behaviour:t='basicSize'
          position:t='absolute'
          id:t='arrow_plate_circle'
          pos:t='(pw-w)/2, (ph-h)/2'
          isCircle:t='yes'
          width:t='pw'
          height-base:t='100'
          height-end:t='0'
          size-func:t='cube'
          size-scale:t='parent'
          size-time:t='250'
          _size-timer:t='1'
        }
        img {
          size:t='pw, ph'
          position:t='absolute'
        }
        tdiv {
          id:t='label'
          position:t='absolute'
          width:t='pw'
          height:t='ph'
          re-type:t='text'
          input-transparent:t='yes'
          color:t='#18202A'
          font:t='@fontSmall'
          text-align:t='center'
          text:t=''
        }
      }
    }
  }

  shopTopUnitBonus {
    id:t='top_units_bonus'
    display:t='hide'

    img {
    }

    topLine{
      position:t='absolute'
      size:t='pw, 1@slotTopLineHeight'
    }
  }

  shopCollapsedButton {
    position:t='absolute'
    id:t='expandbtn_<<containerId>>'
    left:t="0.9@modArrowWidth - 8@sf/@pf"
    padding-right:t='16@sf/@pf + h * 0.2'
    isNavInContainerBtn:t='yes'
    on_click:t='onExpandBtnClick'

    img {
      position:t='relative'
      size:t='16@sf/@pf, w * 0.615'
    }
  }
}
