root {
  blur {}
  blur_foreground {}

  frame {
    width:t='<<maxCountX>>@mapPreferenceIconNestWidth + 1@mapPreferencePreviewFullWidth + <<#hasScroll>>1@scrollBarSize<</hasScroll>>';
    height:t='1@maxWindowHeight'
    max-width:t='1@rw'
    class:t='wnd'
    css-hier-invalidate:t='yes'
    isCenteredUnderLogo:t='yes'
    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<wndTitle>>'
      }

      textarea {
        id:t='counters'
        position:t='relative'
        pos:t='0, 0.5ph-0.5h'
        text:t='<<counterTitle>>'
      }

      Button_close { id:t = 'btn_back' }
    }

    tdiv{
      size:t='pw, ph'
      flow:t='horizontal'
      css-hier-invalidate:t='yes'

      tdiv{
        size:t='fw, ph'
        flow:t='vertical'

        tdiv {
          id:t='search_container'
          width:t='pw -1@framePadding'
          padding:t='-1@framePadding +1@mapPreferenceIconMargin, 0'
          padding-bottom:t='1@framePadding'

          include '%gui/chapter_include_filter.blk'
        }

        tdiv {
          id:t='maps_list'
          size:t='pw, fh'
          padding-left:t='-1@framePadding'
          flow:t='h-flow'
          overflow-y:t='auto'
          behaviour:t='posNavigator'
          navigatorShortcuts:t='noSelect'
          scrollbarShortcuts:t='yes'
          position:t='relative'
          on_select:t='onSelect'
          css-hier-invalidate:t='yes'
          total-input-transparent:t='yes'
          hasPremium:t='<<#premium>>yes<</premium>><<^premium>>no<</premium>>'
          hasMaxBanned:t='<<hasMaxBanned>>'
          hasMaxDisliked:t='<<hasMaxDisliked>>'
          hasMaxLiked:t='<<hasMaxLiked>>'
          <<#maps>>
          mapNest{
            id:t='nest_<<mapId>>'
            flow:t='vertical'
            textStyle:t='mis-map'
            margin:t='1@mapPreferenceIconMargin, 1@blockInterval'
            css-hier-invalidate:t='yes'

            focus_border {}
            iconMap{
              id:t='icon_<<mapId>>'
              position:t='relative'
              state:t='<<state>>'
              css-hier-invalidate:t='yes'

              mapImg{
                id:t='mapIcon'
                mapId:t='<<mapId>>'
                background-image:t = '<<image>>'
                title:t='<<title>>'

                textareaNoTab {
                  padding:t='4@sf/@pf, 0'
                  valign:t='bottom'
                  style:t="color:@white"
                  background-color:t='@blurBgrColor'
                  text:t = '<<brRangeText>>'
                }
              }

              tdiv{
                id:t='cb_nest_<<mapId>>'
                position:t='absolute'
                flow:t='horizontal'
                css-hier-invalidate:t='yes'

                mapStateBox{
                  id:t='disliked'
                  type:t='disliked'
                  mapId:t='<<mapId>>'
                  value:t='<<#disliked>>yes<</disliked>><<^disliked>>no<</disliked>>'
                  display:t='hide'
                  on_change_value:t = 'onUpdateIcon'
                  mapStateBoxImg{}
                }

                mapStateBox{
                  id:t='banned'
                  type:t='banned'
                  mapId:t='<<mapId>>'
                  value:t='<<#banned>>yes<</banned>><<^banned>>no<</banned>>'
                  display:t='hide'
                  on_change_value:t = 'onUpdateIcon'
                  mapStateBoxImg{}
                }

                mapStateBox{
                  id:t='liked'
                  type:t='liked'
                  mapId:t='<<mapId>>'
                  value:t='<<#liked>>yes<</liked>><<^liked>>no<</liked>>'
                  display:t='hide'
                  on_change_value:t = 'onUpdateIcon'
                  mapStateBoxImg{}
                }
              }
            }

            textareaNoTab{
              text:t='<<title>>'
              word-wrap:t='no'
              padding:t='1@blockInterval, 1@blockInterval'
              position:t='relative'
            }
          }
          <</maps>>
        }

        text {
          id:t='empty_list_label'
          pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute'
          display:t='<<#isListEmpty>>show<</isListEmpty>><<^isListEmpty>>hide<</isListEmpty>>'
          text:t='#ui/empty'
        }
      }
      blockSeparator {}

      tdiv{
        height:t='ph'

        tdiv{
          id:t='map_preview'
          width:t='1@mapPreferencePreviewSize + 1@framePadding'
          height:t='ph - 1@buttonHeight - 2@buttonMargin'
          padding-left:t='1@framePadding'
          padding-top:t='1@framePadding'
          flow:t='vertical'
          <<^banListHeight>>
          overflow-y:t='auto'
          <</banListHeight>>
          position:t='relative'
          css-hier-invalidate:t='yes'

          img {
            id:t='img_preview'
            size:t='pw, 1@mapPreferencePreviewSize'
            max-width:t='h'
            max-height:t='w'
            pos:t='0.5pw-0.5w, 1@blockInterval'
            position:t='relative'
            background-image:t=''
            display:t='hide'
          }

          tdiv{
            size:t='pw, 1@mapPreferencePreviewSize + 1@blockInterval'
            flow:t='vertical'
            tdiv {
              id:t='tactical-map'
              size:t='pw, 1@mapPreferencePreviewSize'
              max-width:t='h'
              max-height:t='w'
              pos:t='0.5pw-0.5w, 0'
              position:t='relative'
              display:t='hide'

              tacticalMap {
                size:t='pw, ph'
              }
            }
          }

          tdiv {
            halign:t='center'
            flow:t='vertical'

            textAreaCentered {
              id:t='title'
              halign:t='center'
              class:t='active'
              text:t=''
            }

            textAreaCentered {
              id:t='level_br_range'
              halign:t='center'
              class:t='active'
              text:t=''
            }

            tdiv {
              id:t='paginator'
              height:t='1@buttonHeight'
              halign:t='center'
              navMiddle{
                id:t='paginator_place'
              }
            }
          }

          mapStateBox{
            id:t='dislike'
            type:t='disliked'
            margin:t='0, 1@blockInterval'
            position:t='relative'
            mapStateBoxText {id:t='title'}
            on_change_value:t = 'onUpdateIcon'
            skip-navigation:t='yes'
            btnName:t='X'
            display:t='hide'
            ButtonImg{}
            mapStateBoxImg{}
          }

          mapStateBox{
            id:t='ban'
            type:t='banned'
            margin:t='0, 1@blockInterval'
            position:t='relative'
            mapStateBoxText {id:t='title'}
            <<^premium>>
            inactiveColor:t='yes'
            tooltip:t= '#mainmenu/onlyWithPremium'
            <</premium>>
            on_change_value:t = 'onUpdateIcon'
            skip-navigation:t='yes'
            btnName:t='Y'
            display:t='hide'
            ButtonImg{}
            mapStateBoxImg{}
          }

          mapStateBox{
            id:t='like'
            type:t='liked'
            margin:t='0, 1@blockInterval'
            position:t='relative'
            mapStateBoxText {id:t='title'}
            on_change_value:t = 'onUpdateIcon'
            skip-navigation:t='yes'
            btnName:t='A'
            display:t='hide'
            ButtonImg{}
            mapStateBoxImg{}
          }

          rowSeparator{
            id:t='preview_separator'
            display:t='hide'
          }

          textAreaCentered {
            id:t='listTitle'
            class:t='active'
            width:t='1@mapPreferencePreviewSize'
            text:t='<<listTitle>>'
          }

          tdiv {
            id:t='ban_list'
            width:t='pw'
            flow:t='vertical'
            <<#banListHeight>>
            height:t='<<banListHeight>>'
            overflow-y:t='auto'
            <</banListHeight>>
            scrollbarShortcuts:t='yes'
            position:t='relative'
            css-hier-invalidate:t='yes'

            include "%gui/missions/mapStateBox.tpl"
          }
        }

        Button_text {
          id:t='btnReset'
          left:t='pw-w-1@buttonMargin'
          top:t='ph-h-1@buttonMargin'
          position:t='absolute'
          text:t = '#mainmenu/btnReset'
          display:t='hide'
          on_click:t = 'onResetPreferencess'
          btnName:t='R3'
          ButtonImg {}
        }
      }
    }
  }
  gamercard_div {}

  chatPopupNest {
    id:t='chatPopupNest'
    position:t='absolute'
    pos:t='0.5pw-0.5w, 0'
  }
}