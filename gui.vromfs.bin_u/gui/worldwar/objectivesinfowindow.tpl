frame {
  pos:t='50%pw-50%w, 50%ph-50%h';
  position:t='absolute';
  max-height:t='1@maxWindowHeight';
  class:t='wnd'

  frame_header {
    activeText {
      text:t='#worldWar/wndTitle/Objectives';
      caption:t='yes';
    }

    Button_close {}
  }
  tdiv {
    id:t='operations_info'
    pos:t='0,0'
    position:t='relative'
    size:t='pw, ph'
    flow:t='vertical'
    css-hier-invalidate:t='yes'

    tdiv {
      width:t='pw'
      height:t='fh'

      <<#teamBlock>>
        frameBlock_dark {
          id:t='<<teamName>>'
          width:t='1@wwMapPanelInfoWidth'
          height:t='ph'
          padding:t='1@framePadding'
          flow:t='vertical'
          position:t='relative'
          bgTeamColor:t='<<teamColor>>'
        }
      <</teamBlock>>
    }
  }
}
