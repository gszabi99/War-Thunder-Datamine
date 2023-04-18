root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    width:t='80%sh'
    height:t='60%sh'
    max-width:t='800*@sf/@pf_outdated + 2@framePadding'
    max-height:t='@rh'
    class:t='wndNav'

    frame_header {
      activeText {
        caption:t='yes'
        text:t='<<headerText>>'
      }
      Button_close {}
    }

    frameBlock {
      size:t='pw, fh'
      padding:t='3*@sf/@pf_outdated';
      overflow-y:t='auto';
      scrollbarShortcuts:t='yes'

      tdiv {
        id:t='teamA'
        width:t='0.5fw'
        padding:t='1@blockInterval'
        flow:t='vertical'

        activeText {
          text:t='#events/teamA';
        }
        tdiv {
          id:t='countries';
        }
        textareaNoTab {
          id:t='players_count'
          width:t='pw'
          hideEmptyText:t='yes'
          text:t='';
        }
        tdiv {
          id:t='allowed_unit_types';
          flow:t='vertical';
          margin-bottom:t='0.01@sf'
          activeText {
            id:t='allowed_unit_types_text';
            text:t='#events/all_units_allowed';
          }
        }
        tdiv {
          id:t='required_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/required_crafts';
          }
        }
        tdiv {
          id:t='allowed_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/allowed_crafts';
          }
        }
        tdiv {
          id:t='forbidden_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/forbidden_crafts';
          }
        }
      }

      chapterSeparator{
        position:t='relative';
        pos:t='0, ph/2 - h/2'
      }

      tdiv {
        id:t='teamB';
        width:t='0.5fw';
        padding:t='1@blockInterval'
        flow:t='vertical';

        activeText {
          text:t='#events/teamB';
        }
        tdiv {
          id:t='countries';
        }
        textareaNoTab {
          id:t='players_count'
          width:t='pw'
          hideEmptyText:t='yes'
          text:t='';
        }
        tdiv {
          id:t='allowed_unit_types';
          flow:t='vertical';
          margin-bottom:t='0.01@sf'
          activeText {
            id:t='allowed_unit_types_text';
            text:t='#events/all_units_allowed';
          }
        }
        tdiv {
          id:t='required_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/required_crafts';
          }
        }
        tdiv {
          id:t='allowed_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/allowed_crafts';
          }
        }
        tdiv {
          id:t='forbidden_crafts';
          flow:t='vertical';
          activeText {
            text:t='#events/forbidden_crafts';
          }
        }
      }
    }

    navBar {
      navRight {
        Button_text {
          id:t='btn_close'
          text:t='#mainmenu/btnOk'
          btnName:t='A'
          _on_click:t='goBack'
          ButtonImg {}
        }
      }
    }
  }
}
