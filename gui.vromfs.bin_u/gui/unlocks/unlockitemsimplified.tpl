<<#unlocks>>
expandable {
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
        decal_locked:t='no';
        achievement_locked:t='no';
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
          max-width:t='pw';
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

        challengeDescriptionProgress{
          id:t='progress_bar';
          value:t='';
          display:t='hide';
          style:t='width:pw;';
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

      <<#hasCloseButton>>
      Button_close {
        id:t='removeFromFavoritesBtn'
        smallIcon:t='yes'
        on_click:t='onRemoveUnlockFromFavorites'
        tooltip:t='#mainmenu/UnlockAchievementsRemoveFromFavorite/hint'
        unlockId:t='null'
        }
      <</hasCloseButton>>
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
      id:t='hidden_block';
      isSmallView:t = 'yes';
      width:t='pw';
      padding:t='0, 0, 1*@scrn_tgt/100.0, 0'
      flow:t='h-flow'
    }
  }
}
<</unlocks>>