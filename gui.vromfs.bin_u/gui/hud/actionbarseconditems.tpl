tdiv {
  position:t='relative'
  flow:t='vertical'
  pos:t='<<posx>> -w/2 + 0.5@hudActionBarItemSize - sw/2, -h - 5@dp - <<posy>>'
  <<#header>>
  tdiv {
    width:t='<<itemsCount>>*(1@dp + 1@hudActionBarItemSize)'
    max-width:t='pw'
    position:t='relative'
    re-type:t='9rect'
    background-color:t='#C0FFFFFF'
    background-repeat:t='expand'
    background-position:t='4, 4, 4, 4'
    background-image:t='#ui/gameuiskin#block_bg_rounded_gray'
    padding-top:t='0.002@shHud'
    textarea {
      position:t='relative'
      text-align:t='center'
      width:t='pw'
      hudFont:t='small'
      color:t='@hotkeyColor'
      text:t='<<header>>'
    }
  }
  <</header>>

  second_action_shortcuts {
    flow:t='h-flow'
    re-type:t='9rect'
    background-color:t='#C0FFFFFF'
    background-repeat:t='expand'
    background-position:t='4, 4, 4, 4'
    background-image:t='#ui/gameuiskin#block_bg_rounded_gray'
    padding-top:t='0.002@shHud'
    <<#shortcuts>>
      <<#isXinput>>
        tdiv {
          position:t='relative'
          width:t='1@hudActionBarItemSize + 1@dp'
          padding-top:t='3@dp'
          padding-bottom:t='3@dp'
          tdiv {
            id:t='mainActionButton'
            behaviour:t='BhvHint'
            position:t='relative'
            pos:t='pw/2 - w/2, 0'
            value:t='{{<<mainShortcutId>>}}'
          }
        }
      <</isXinput>>
      <<^isXinput>>
        textarea {
          position:t='relative'
          text-align:t='center'
          width:t='1@hudActionBarItemSize + 1@dp'
          hudFont:t='small'
          color:t='@hotkeyColor'
          text:t=<<shortcut>>
        }
      <</isXinput>>
    <</shortcuts>>
  }
  tdiv {
    id:t='secondItemsRow'
    flow:t='h-flow'
    <<#items>>
      tdiv {
        position:t='relative'
        flow:t='vertical'
        include "%gui/hud/actionBarItem.tpl"
        padding:t='0, 1@dp, 1@dp, 1@dp'
      }
    <</items>>
  }
  tdiv {
    flow:t='h-flow'
    re-type:t='9rect'
    padding-top:t='0.002@shHud'
    background-color:t='#C0FFFFFF'
    background-repeat:t='expand'
    background-position:t='4, 4, 4, 4'
    background-image:t='#ui/gameuiskin#block_bg_rounded_gray'
    <<#actionShortNames>>
      textarea {
        position:t='relative'
        text-align:t='center'
        width:t='1@hudActionBarItemSize + 1@dp'
        hudFont:t='small'
        shortcut:t='yes'
        text:t=<<shortName>>
      }
    <</actionShortNames>>
  }
}
