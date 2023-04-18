tdiv {
  id:t = 'panel';
  width:t = '<<panelWidth>><<^panelWidth>>@defaultNavPanelWidth<</panelWidth>>';
  height:t = 'ph';
  flow:t = 'horizontal';
  total-input-transparent:t='yes'

  tdiv {
    size:t = 'fw, ph';
    flow:t = 'vertical';

    tdiv {
      id:t = 'panel_header';
      width:t = 'pw';
      height:t = '<<headerHeight>><<^headerHeight>>0.05@sf<</headerHeight>>';
      margin-left:t   = '<<headerOffsetX>>';
      margin-right:t  = '<<headerOffsetX>>';
      margin-top:t    = '<<headerOffsetY>>';
      margin-bottom:t = '<<headerOffsetY>>';
      flow:t = 'horizontal';

      textareaNoTab {
        width:t = 'fw';
        padding:t = '0.01@sf, 0';
        overflow:t = 'hidden';
        caption:t = 'yes'
        text-align:t = 'center';
        valign:t = 'center';
        text:t    = '#mainmenu/navigation';
        tooltip:t = '#mainmenu/navigation';
      }

      <<#needShowCollapseButton>>
        emptyButton {
          id:t = 'collapse_button';
          class:t = 'navigationCollapse';
          height:t = '1@buttonHeight';
          tooltip:t = '#mainmenu/btnCollapse';
          <<#collapseShortcut>>
            btnName:t = '<<collapseShortcut>>';
          <</collapseShortcut>>
          on_click:t = 'onNavCollapse';
          icon {
            rotation:t = '270';
          }
          ButtonImg {}
        }
      <</needShowCollapseButton>>
    }

    listboxNoScroll {
      id:t = 'nav_list';
      size:t = 'pw, fh';
      class:t = 'navigationItemList'
      overflow-y:t = 'auto';
      navigatorShortcuts:t='yes'
      move-only-hover:t='yes'
      on_select:t = 'onNavSelect'
      on_click:t = 'onNavClick'
      _on_hover:t='updateMoveToPanelButton'
      _on_unhover:t='updateMoveToPanelButton'
    }

    <<#focusShortcut>>
    tdiv {
      size:t='pw, 1@buttonHeight'
      Button_text{
        id:t = 'moveToLeftPanel'
        position:t='relative'
        pos:t='0.5pw-0.5w, 0'
        visualStyle:t='noBgr'
        noMargin:t='yes'
        text:t='#mainmenu/btnMoveToNavPanel'
        color:t='commonTextColor'
        display:t='hide'
        enable:t='no'
        btnName:t = '<<focusShortcut>>'
        on_click:t = 'onFocusNavigationList'
        skip-navigation:t='yes'
        focus_border {}
        ButtonImg {}
      }
    }
    <</focusShortcut>>
  }

  chapterSeparator {margin:t='1@blockInterval, 0'}
}

emptyButton {
  id:t = 'expand_button';
  class:t = 'navigationExpand';
  position:t = 'absolute';
  left:t = '<<headerOffsetX>>';
  top:t  = '<<headerOffsetY>>';
  height:t = '1@buttonHeight';
  tooltip:t = '#mainmenu/navigationExpand';
  <<#expandShortcut>>
    btnName:t = '<<expandShortcut>>'
  <</expandShortcut>>
  on_click:t = 'onExpand';
  ButtonImg {}
  icon {
    rotation:t = '90';
  }
}
