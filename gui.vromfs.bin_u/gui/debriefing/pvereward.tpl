tdiv {
  width:t='pw'
  flow:t='vertical'

  everyDayRewardProgress
  {
    id:t='new_progress_box'
    foreground-color:t='@red'
    width:t='pw - 1@sliderThumbWidth'
    height:t='1@loopProgressHeight'
    pos:t='50%pw-50%w, 50%ph-50%h'
    value:t='<<value>>'
    style:t='max:<<maxValue>>'
    pattern { type:t='dark_diag_lines' }
  }

  tdiv {
    width:t='pw - 1@sliderThumbWidth'
    pos:t='0, 50%ph-50%h'
    position:t='absolute'
    <<#stage>>
    tdiv {
      pos:t='<<posX>>*pw, 50%ph-50%h'
      position:t='absolute'
      height:t='3@progressHeight'

      img {
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='absolute'
        size:t='1@dp+4, ph'
        background-image:t='#ui/gameuiskin#drop_menu_separator'
        background-repeat:t='expand'
        background-position:t='2'
      }

      textareaNoTab {
        pos:t='50%pw-50%w, ph'
        position:t='absolute'
        text:t='<<text>>'
        hideEmptyText:t='yes'
      }

      <<#trophy>>
      tdiv {
        pos:t='50%pw-50%w, -h'
        position:t='absolute'
        smallItems:t='yes'
        <<@trophy>>

        <<#isReceived>>
          img {
            pos:t='50%pw-20%w, 50%ph-50%h'
            position:t='absolute'
            size:t='1@mIco, 1@mIco'
            background-image:t='#ui/gameuiskin#check.svg'
            background-svg-size:t='1@mIco, 1@mIco'
            input-transparent:t='yes'
          }
        <</isReceived>>
      }
      <</trophy>>
    }
    <</stage>>
  }
}
