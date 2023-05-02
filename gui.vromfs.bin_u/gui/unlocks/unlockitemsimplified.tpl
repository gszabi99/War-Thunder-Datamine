<<#unlocks>>
expandable {
  id:t=''
  class:t='unlock';

  selImg {
    id:t='unlock_block'
    width:t='pw';
    mainDescWrap{
      padding:t='1@unlockSimplifiedDescPadding';
      padding-right:t='1.5*@sf/100.0';
      width:t='pw';

      layeredIconContainer{
        id:t='achivment_ico';
        size:t='0.5*@profileUnlockIconSize, 0.5*@profileUnlockIconSize';
        position:t='relative';
        pos:t='0, ph/2 - h/2';
      }

      achievementTitle{
        padding-top:t='0.5@sf/100.0';
        margin-left:t='1.5*@sf/100.0';
        min-height:t='0.5*@profileUnlockIconSize';
        width:t='fw';
        smallFont:t='yes'
        flow:t='vertical';

        activeText{
          id:t='achivment_title';
          text:t='';
          max-width:t='pw-1.5@smallButtonCloseHeight'
          pare-text:t='yes';
          overlayTextColor:t='unlockHeader'
        }

        textarea{
          id:t='description';
          short-description:t='yes'
          width:t='pw';
          overflow:t='hidden';
          smallFont:t='yes';
          style:t='wrap-indent: 0; paragraph-indent: 0;';
          text:t='';
        }

        tdiv {
          size:t='pw-@blockInterval, @progressHeight'
          margin-top:t='0.01@sf'

          favoriteUnlockProgress {
            id:t='progress_bar'
            position:t='absolute'
            value:t=''
            display:t='hide'
            width:t='pw'
          }
          favoriteUnlockSnapshot {
            id:t='progress_snapshot'
            position:t='absolute'
            value:t=''
            display:t='hide'
            width:t='pw'
          }
        }

        textarea{
          id:t='reward';
          text:t='';
          smallFont:t='yes';
          margin-top:t='1.15*@sf/100.0';
          style:t='wrap-indent: 0; paragraph-indent: 0;';
          max-width:t='pw';
          pare-text:t= 'yes';
        }
      }

      Button_text {
        id:t='snapshotBtn'
        position:t='absolute'
        right:t='@smallButtonCloseHeight'
        class:t='image'
        imgSize:t='small'
        visualStyle:t='noFrame'
        tooltip:t='#unlock/save_snapshot'
        unlockId:t=''
        on_click:t='onStoreSnapshot'
        img {
          background-image:t='#ui/gameuiskin#calendar_date.svg'
        }
      }

      Button_close {
        id:t='removeFromFavoritesBtn'
        smallIcon:t='yes'
        on_click:t='onRemoveUnlockFromFavorites'
        tooltip:t='#mainmenu/UnlockAchievementsRemoveFromFavorite/hint'
        unlockId:t='null'
      }
    }

    expandImg {
      id:t='expandImg';
      height:t='1*@scrn_tgt/100.0';
      width:t='2h';
      pos:t='50%pw-50%w, ph-h-0.7*@sf/100.0'; position:t='absolute';
      background-image:t='#ui/gameuiskin#expand_info';
      background-color:t='@premiumColor';
      display:t='hide';
    }

    hiddenDiv{
      id:t='hidden_block'
      isSmallView:t = 'yes'
      padding:t='0, 0, 1*@scrn_tgt/100.0, 0'
      width:t='pw'
      flow:t='h-flow'
    }

    img {
      id:t="lock_icon"
      display:t="hide"
      pos:t="10@sf/@pf, 10@sf/@pf"; position:t="absolute"
      background-image:t="#ui/gameuiskin#locked.svg"
      size:t="@cIco,@cIco"
      background-svg-size:t="@cIco,@cIco"
      background-color:t="@white"
    }
  }

  title:t='$tooltipObj'
  tooltipObj {
    id:t='unlock_tooltip'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
}
<</unlocks>>