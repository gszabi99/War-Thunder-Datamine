root {
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    size:t='1@maxWindowWidth $min (<<countriesTotal>>*320@sf/@pf +1@scrollBarSize), 1@maxWindowHeightNoSrh'
    pos:t='pw/2-w/2, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)'
    position:t='absolute'
    class:t='wnd'

    frame_header {
      activeText { id:t='wnd_title'; caption:t='yes'; text:t='<<windowTitle>>' }
      Button_close {}
    }

    tdiv {
      size:t='pw, fh'
      flow:t='vertical'

      tdiv {
        width:t='pw - 1@scrollBarSize'
        <<#countries>>
        tdiv {
          width:t='320@sf/@pf'
          max-width:t='pw/<<countriesCount>>'
          frameBlock {
            width:t='pw'
            margin-right:t='1@blockInterval'
            margin-bottom:t='1@blockInterval'
            padding:t='0.01@scrn_tgt'
            flow:t='vertical'

            cardImg {
              pos:t='pw/2-w/2, 0'
              position:t='relative'
              background-image:t='<<countryIcon>>'
            }
          }
        }
        <</countries>>
      }

      tdiv {
        size:t='pw, fh'
        overflow-y:t='auto'
        scrollbarShortcuts:t='yes'

        tdiv {
          id:t='contentBlock'
          width:t='fw - 1@scrollBarSize'
          min-height:t='ph'

          <<#countries>>
          tdiv {
            width:t='320@sf/@pf'
            max-width:t='pw/<<countriesCount>>'
            min-height:t='ph'
            frameBlock {
              min-height:t='ph'
              width:t='pw'
              margin-right:t='1@blockInterval'
              padding:t='0.01@scrn_tgt'

              flow:t='vertical'

              <<#armyTypes>>
              tdiv {
                width:t='pw'
                flow:t='vertical'
                activeText {
                  pos:t='0, 0.01@sf'
                  position:t='relative'
                  parseTags:t='yes'
                  text:t='<<armyName>>'
                }

                <<#units>>
                emptyButton {
                  id:t='btn_<<id>>'
                  width:t='pw - 0.01@sf'
                  margin-left:t='0.01@sf'
                  smallFont:t='yes'
                  on_click:t='onUnitClick'

                  img {
                    pos:t='20%w, ph/2-h/2'
                    position:t='relative'
                    background-image:t='<<ico>>'
                    shopItemType:t='<<type>>'
                    size:t='@tableIcoSize, @tableIcoSize'
                    background-svg-size:t='@tableIcoSize, @tableIcoSize'
                    background-repeat:t='aspect-ratio'
                    input-transparent:t='yes'
                  }
                  activeText {
                    pos:t='0, ph/2-h/2'
                    position:t='relative'
                    width:t='fw'
                    padding-left:t='4*@sf/@pf_outdated'
                    input-transparent:t='yes'
                    parseTags:t='yes'
                    text:t='<<text>>'

                    <<#isUsable>>
                    airBought:t='yes'
                    <</isUsable>>
                    <<^isUsable>>
                    <<#canBuy>>
                    airCanBuy:t='yes'
                    <</canBuy>>
                    <<^canBuy>>
                    airCanBuy:t='no'
                    <</canBuy>>
                    <</isUsable>>
                  }
                  tooltipObj {
                    tooltipId:t='<<tooltipId>>'
                    on_tooltip_open:t='onGenericTooltipOpen'
                    on_tooltip_close:t='onTooltipObjClose'
                    display:t='hide'
                  }
                  title:t='$tooltipObj'
                }
                <</units>>

                <<#unitPlates>>
                slotbarPresetsTable {
                  id:t='btn_<<id>>'
                  total-input-transparent:t='yes'
                  flow:t='horizontal'

                  behavior:t='posNavigator'
                  navigatorShortcuts:t='active'
                  on_select:t='onUnitClick'
                  move-only-hover:t='yes'

                  <<@plateMarkup>>
                }
                <</unitPlates>>
              }
              <</armyTypes>>
            }
          }
          <</countries>>
        }
      }
    }
  }

  gamercard_div {
    include 'gui/gamercardTopPanel.blk'
    include 'gui/gamercardBottomPanel.blk'
  }
}
