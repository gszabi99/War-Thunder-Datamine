popup_menu {
  id:t='popup_list'
  position:t='root'
  not-input-transparent:t='yes'
  css-hier-invalidate:t='yes'

  rootUnderPopupMenu {
    on_click:t='<<underPopupClick>>'
    on_r_click:t='<<underPopupDblClick>>'
    <<#clickPropagation>>
    access-key:t='no'
    <</clickPropagation>>

    DummyButton {
      btnName:t='B'
      on_click:t = 'goBack'
    }
  }

  tdiv {
    id:t='branch_list'
    max-height:t='0.9@rh'
    flow:t='vertical'
    overflow-y:t='auto'
    <<#branches>>
      <<^hasBranches>>
        include "%gui/commonParts/button.tpl"
      <</hasBranches>>
      <<#hasBranches>>
        listBranch {
          id:t='<<branchName>>'
          position:t='relative'
          padding-bottom:t='4@sf/@pf'
          flow:t='vertical'
          isBranchOpened:t='yes'

          listBranchHeader {
            position:t='relative'
            min-width:t='<<btnWidth>>'
            flow:t='horizontal'
            input-transparent:t='no'
            padding-left:t='4@sf/@pf'
            behavior:t='button'
            on_click:t='onBranchBtnClick'

            listBranchStateText {
              id:t='collapse_text'
              css-hier-invalidate:t='yes'
              input-transparent:t='yes'
              text:t='-'
            }
            textareaNoTab {
              margin-left:t='4@sf/@pf'
              input-transparent:t='yes'
              text:t='<<branchLocName>>'
            }
          }

          listBranchContent {
            flow:t='vertical'
            <<#branches>>
              include "%gui/commonParts/button.tpl"
            <</branches>>
          }
        }
      <</hasBranches>>
    <</branches>>
  }

  popup_menu_arrow {}
}
