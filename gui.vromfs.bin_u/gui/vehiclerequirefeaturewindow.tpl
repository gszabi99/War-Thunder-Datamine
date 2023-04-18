root {
  blur {}
  blur_foreground {}

  frame {
    pos:t='50%pw-50%w, 50%ph-50%h';
    position:t='absolute';
    width:t='80%sh';
    max-width:t='800*@sf/@pf_outdated + 2@framePadding';
    max-height:t='@rh'
    class:t='wndNav';

    timer {
      id:t='vehicle_require_feature_timer';
      timer_handler_func:t='onTimerUpdate';
    }

    frame_header {
      activeText {
        caption:t='yes';
        text:t='<<headerText>>';
      }
      Button_close {}
    }

    img {
      width:t='pw';
      height:t='0.375w';
      max-width:t='800*@sf/@pf_outdated';
      max-height:t='300*@sf/@pf_outdated';
      pos:t='50%pw-50%w, 0';
      position:t='relative';
      background-image:t='<<windowImage>>';
    }

    tdiv {
      width:t='pw';
      max-height:t='fh';
      pos:t='0, 0.005@scrn_tgt';
      position:t='relative';
      flow:t='vertical';
      overflow-y:t='auto';

      textarea {
        width:t='pw';
        chapterTextAreaStyle:t='yes';
        hideEmptyText:t='yes';
        font-bold:t='@fontMedium';
        text:t='<<mainText>>';
        padding-left:t='0.02@sf';
        on_link_click:t='proccessLinkFromText'
      }
    }

    <<#showEntitlementsTable>>
    table {
      id:t='items_list';
      class:t='crewTable';
      pos:t='0.5(pw-w), 0.03sh';
      position:t='relative';
      behavior:t = 'PosNavigator';

      <<#entitlements>>
      tr{
        <<#rowEven>>
        even:t='yes';
        <</rowEven>>
        <<^rowEven>>
        even:t='no';
        <</rowEven>>

        td {
          cellType:t='left';
          padding-left:t='5*@scrn_tgt/100.0';

          textarea {
            id:t='amount';
            class:t='active';
            text-align:t='right';
            overlayTextColor:t='active'
            min-width:t='0.13@sf';
            max-width:t='0.7@sf';
            text:t='<<entitlementName>>';
            valign:t='center';
          }
        }
        td {
          <<#entitlementCostShow>>
          textarea {
            class:t='active';
            text-align:t='right';
            overlayTextColor:t='active'
            min-width:t='0.13@sf';
            text:t='<<entitlementCost>>';
            valign:t='center';
          }
          <</entitlementCostShow>>
          <<#discountShow>>
          discount {
            text:t='<<discountText>>';
            pos:t='0, -5%h';
            position:t='relative';
            rotation:t='8';
          }
          <</discountShow>>
        }
        td {
          id:t='holder'
          padding-right:t='5*@scrn_tgt/100.0'

          Button_text {
            id:t='buttonBuy';
            on_click:t='onRowBuy';
            pos:t='0, 50%ph-50%h';
            position:t='relative';
            showOn:t='hoverOrPcSelect'
            btnName:t='A';
            noMargin:t='yes'
            entitlementId:t='<<entitlementId>>';
            ButtonImg {}

            <<^externalLink>>
            text:t='#mainmenu/btnBuy';
            <</externalLink>>

            <<#externalLink>>
            text:t='';
            externalLink:t='yes';
            activeText {
              position:t='absolute';
              pos:t='0.5pw-0.5w, 0.5ph-0.5h - 2@sf/@pf_outdated';
              text:t='#mainmenu/btnBuy';
              underline {}
            }
            <</externalLink>>
          }
        }
      }
      <</entitlements>>
    }
    <</showEntitlementsTable>>

    <<#showOkButton>>
    navBar {
      navRight {
        Button_text {
          id:t='btn_close';
          text:t='#mainmenu/btnOk';
          btnName:t='A';
          _on_click:t='goBack';
          ButtonImg {}
        }
      }
    }
    <</showOkButton>>
  }
}
