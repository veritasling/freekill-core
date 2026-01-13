// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Layouts

import Fk
import LunarLtk

RowLayout {
  id: root

  required property DashboardModel dataModel

  Connections {
    target: dataModel
    function onHandcardsSorted() {
      const sortedCards = [];
      const cards = handcardAreaItem.cards;
      for (const model of dataModel.handcards) {
        const i = cards.findIndex(cd => cd.dataModel === model);
        if (i !== -1) sortedCards.push(cards.splice(i, 1)[0]);
      }
      sortedCards.push(...cards);
      handcardAreaItem.cards = sortedCards;
      handcardAreaItem.updateCardPosition(true);
    }
  }

  property var self
  property alias handcardArea: handcardAreaItem

  property string pending_skill: ""
  property bool sortable: true
  property var pending_card
  property var pendings: [] // int[], store cid
  property int selected_card: -1

  property alias skillButtons: skillPanel.skill_buttons
  property alias notActiveButtons: skillPanel.not_active_buttons

  property var disabledSkillNames: []

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
  }

  SkillArea {
    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.maximumWidth: width
    Layout.maximumHeight: height
    Layout.alignment: Qt.AlignBottom
    Layout.bottomMargin: 32
    Layout.rightMargin: -16
    id: skillPanel
  }

  Item {
    Layout.preferredWidth: 175
    Layout.preferredHeight: 233
    Layout.rightMargin: -175 / 8 + (roomArea.width - 175 * 0.75 * 7) / 8
    // handcards: handcardAreaItem.length
  }

  Connections {
    target: handcardAreaItem
    function onCardSelected(cardId, selected) {
      Ltk.updateRequestUI("CardItem", cardId, "click", { selected, autoTarget: Config.autoTarget } );
    }
    function onCardDoubleClicked(cardId, selected) {
      Ltk.updateRequestUI("CardItem", cardId, "doubleClick", { selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget } );
    }
    function onLengthChanged() {
      self.dataModel.updateHandcards();
    }
  }

  function disableAllCards() {
    handcardAreaItem.enableCards([]);
  }

  function unSelectAll(expectId) {
    handcardAreaItem.unselectAll(expectId);
  }

  function addSkill(skill_name, prelight) {
    skillPanel.addSkill(skill_name, prelight);
  }

  function loseSkill(skill_name, prelight) {
    skillPanel.loseSkill(skill_name, prelight);
  }

  function prelightSkill(skill_name, prelight) {
    const btns = skillPanel.prelight_buttons;
    for (let i = 0; i < btns.count; i++) {
      const btn = btns.itemAt(i);
      if (btn.orig === skill_name) {
        btn.prelighted = prelight;
        btn.enabled = true;
      }
    }
  }

  function disableSkills() {
    disabledSkillNames = [];
    for (let i = 0; i < skillButtons.count; i++)
      skillButtons.itemAt(i).enabled = false;
  }

  function tremble() {
    self.tremble();
  }

  function updateHandcards() {
    Lua.selfPlayer.filterHandcards();
    handcardAreaItem.cards.forEach(v => {
      v.setData(Ltk.getCardData(v.cid, true));
    });
  }

  function update() {
    unSelectAll();
    disableSkills();
    sortable = handcardAreaItem.sortable;

    let cards = handcardAreaItem.cards;
    const toRemove = [];
    for (let c of cards) {
      toRemove.push(c.cid);
      c.origY += 30;
      c.origOpacity = 0
      c.goBack(true);
      c.destroyOnStop();
    }
    handcardAreaItem.remove(toRemove);

    skillPanel.clearSkills();

    const self = Lua.selfPlayer;
    for (const s of self.player_skills) {
      addSkill(s.name);
    }

    const cids = self.getCardIds("h");
    const visibleData = {};
    for (const cid of cids) {
      visibleData[cid.toString()] = self.cardVisible(cid);
    }
    cards = roomScene.drawPile.remove(cids, null, visibleData);
    handcardAreaItem.add(cards);
  }

  function applyChange(uiUpdate) {
    // TODO: 先确定要不要展开相关Pile
    // card - HandcardArea
    const parentPos = roomScene.mapFromItem(self, 0, 0);
    const component = Qt.createComponent("LunarLtk.Components", "CardItem");

    uiUpdate["_delete"]?.forEach(data => {
      if (data.type == "CardItem") {
        const card = handcardAreaItem.remove([Ltk.createCardModel(data.id)])[0];
        card.origX = parentPos.x;
        card.origY = parentPos.y;
        card.destroyOnStop();
        card.goBack(true);
      }
    });
    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type == "CardItem") {
        const card = component.createObject(roomScene, {
          x: parentPos.x,
          y: parentPos.y,
          dataModel: Ltk.createCardModel(dat.data.id),
        });
        card.footnoteVisible = true;
        card.markVisible = false;
        card.footnote = Lua.tr(dat.ui_data.footnote);
        const vcard = Ltk.getVirtualEquipData(0, dat.data.id);
        if (vcard) {
          card.dataModel.virtName = vcard.name;
        }
        handcardAreaItem.add(card);
      }
    });
    handcardAreaItem.applyChange(uiUpdate);
    sortable = handcardAreaItem.sortable;
    // skillBtn - SkillArea
    const skDatas = uiUpdate["SkillButton"]
    skDatas?.forEach(skdata => {
      for (let i = 0; i < skillButtons.count; i++) {
        const skillBtn = skillButtons.itemAt(i);
        if (skillBtn.orig == skdata.id) {
          skillBtn.enabled = skdata.enabled;
          skillBtn.pressed = skdata.selected;
          break;
        }
      }
    });

    pending_skill = Ltk.getPendingSkill();
  }
}
