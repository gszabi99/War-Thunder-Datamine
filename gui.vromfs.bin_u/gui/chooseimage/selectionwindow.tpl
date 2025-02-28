root {
  behaviour:t='button'
  class:t='button'
  blur {}
  blur_foreground {}

  frame {
    id:t='wnd_frame'
    flow:t='vertical'
    class:t='wndNav'
    isCenteredUnderLogo:t='yes'
    css-hier-invalidate:t='yes'

    frame_header {
      css-hier-invalidate:t='yes'
      activeText {
        id:t='wnd_title'
        caption:t='yes'
        text:t='<<wndTitle>>'
      }
      Button_close { id:t = 'btn_back' }
    }

    tdiv {
      position:t='relative'
      width:t='pw'
      min-height:t='1@buttonHeight + 2@buttonImgPadding'

      popupFilter {
        margin-bottom:t="1@buttonMargin"
      }
      <<#hasSearchBox>>
      tdiv {
        position:t='absolute'
        flow:t='horizontal'
        left:t='p.p.w - w - 15@sf/@pf'

        EditBox {
          id:t = 'search_edit_box'
          width:t='400@sf/@pf'
          noMargin:t='yes'
          edit-hint:t='#contacts/search_placeholder'
          max-len:t='60'
          text:t=''
          on_change_value:t='onSearchEditBoxChangeValue'
          on_cancel_edit:t='onSearchEditBoxCancelEdit'
        }

        Button_text {
          id:t='search_btn_close'
          position:t='relative'
          class:t='image'
          showConsoleImage:t='no'
          noMargin:t='yes'
          tooltip:t='#options/clearIt'
          hotkeyLoc:t='key/Esc'
          on_click:t='onSearchCancelClick'
          img {
            background-image:t='#ui/gameuiskin#btn_close.svg'
          }
        }
      }
      <</hasSearchBox>>
    }

    tdiv {
      id:t='images_list'
      flow:t='h-flow'
      width:t='pw'
      height:t='ph'

      behavior:t='posNavigator'
      navigatorShortcuts:t='yes'
      showSelect:t='always'
      on_click:t='onImageChoose'
      on_dbl_click:t='onImageChoose'
    }

    navBar {
      navMiddle{
        id:t='paginator_place'
      }
      navRight {
        <<#hasDeleteBtn>>
        Button_text {
          id:t='btn_delete'
          text:t='#msgbox/btn_remove'
          btnName:t='X'
          on_click:t='onDeleteBtn'
          showButtonImageOnConsole:t='no'
          class:t='image'
          img{ background-image:t='#ui/gameuiskin#icon_trash_bin.svg' }
          ButtonImg {}
        }
        <</hasDeleteBtn>>
        Button_text {
          id:t='btn_select'
          btnName:t='A'
          text:t='#ugm/btnGoToCategory'
          _on_click:t='onAction'
          visualStyle:t='secondary'
          buttonWink{}
          ButtonImg {}
        }
      }
    }
  }
}
