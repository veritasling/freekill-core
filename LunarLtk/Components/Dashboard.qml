// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import LunarLtk

RowLayout {
  id: root

  required property DashboardModel dataModel

  property alias handcardArea: handcardAreaItem
  property alias sortable: handcardAreaItem.sortable
  property alias skillArea: skillArea
  property alias skillButtons: skillArea.skill_buttons
  property alias notActiveButtons: skillArea.not_active_buttons

  signal cardSelected(var card)

  Item {
    Layout.preferredWidth: 5
  }

  HandcardArea {
    id: handcardAreaItem
    Layout.fillWidth: true
    Layout.preferredHeight: 130
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 24
    onWidthChanged: updateCardPosition(true);

    dataModel: root.dataModel
  }

  SkillArea {
    id: skillArea
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.maximumWidth: width
    Layout.maximumHeight: height
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 32
    Layout.rightMargin: -16

    dataModel: root.dataModel
  }

  Item {
    Layout.preferredWidth: 175
    Layout.preferredHeight: 233
    Layout.rightMargin: -175 / 8 + (roomArea.width - 175 * 0.75 * 7) / 8
  }

  Connections {
    target: handcardAreaItem
    function onCardSelected(cardId, selected) {
      Ltk.updateRequestUI("CardItem", cardId, "click", { selected, autoTarget: Config.autoTarget } );
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function prelightSkill(skill_name, prelight) {
    const btns = skillArea.prelight_buttons;
    for (let i = 0; i < btns.count; i++) {
      const btn = btns.itemAt(i);
      if (btn.orig === skill_name) {
        btn.prelighted = prelight;
        btn.enabled = true;
      }
    }
  }

  function disableSkills() {
    for (let i = 0; i < skillButtons.count; i++)
      skillButtons.itemAt(i).enabled = false;
  }

  function updateHandcards() {
    Lua.selfPlayer.filterHandcards();
    handcardAreaItem.cards.forEach(v => {
      v.setData(Ltk.getCardData(v.cid, true));
    });
  }

  function update() {
    handcardAreaItem.unselectAll();

    skillArea.clearSkills();
    const self = Lua.selfPlayer;
    for (const s of self.player_skills) {
      addSkill(s.name);
    }
  }

  function applyChange(uiUpdate) {
    dataModel.applyChange(uiUpdate);
    handcardAreaItem.applyChange(uiUpdate);

    // skillBtn - SkillArea
    uiUpdate["SkillButton"]?.forEach(skdata => {
      for (let i = 0; i < skillButtons.count; i++) {
        const skillBtn = skillButtons.itemAt(i);
        if (skillBtn.orig == skdata.id) {
          skillBtn.enabled = skdata.enabled;
          skillBtn.pressed = skdata.selected;
          break;
        }
      }
    });
  }
}
