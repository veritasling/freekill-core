// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import Fk
import LunarLtk
import LunarLtk.Components

Item {
  id: root

  required property DashboardModel dataModel

  property alias cards: cardArea.cards
  property alias length: cardArea.length
  property bool sortable: true
  property var selectedCards: []
  property var movepos

  property var draggingCard
  property var draggingClickedPhoto

  signal cardSelected(int cardId, bool selected)

  Connections {
    target: root.dataModel
    function onHandcardsSorted() {
      root.syncCards();
    }
  }

  CardArea {
    id: cardArea
    anchors.fill: parent
    onLengthChanged: root.updateCardPosition(true);
  }

  function add(inputs) {
    cardArea.add(inputs);
    if (inputs instanceof Array) {
      for (let i = 0; i < inputs.length; i++)
        filterInputCard(inputs[i]);
    } else {
      filterInputCard(inputs);
    }
  }

  function filterInputCard(card) {
    card.markVisible = true;
    card.autoBack = true;
    // 只有会被频繁刷新的手牌才能拖动
    // card.draggable = Ltk.canSortHandcards(Cpp.self.id);
    card.dataModel.selectable = false;
    card.clicked.connect(selectCard);
    card.clicked.connect(adjustCards);
    // card.doubleClicked.connect(doubleClickCard);
    card.released.connect(updateCardReleased);
    card.startDrag.connect(updateCardDragging);
  }

  function remove(outputs) {
    const result = cardArea.remove(outputs);
    for (const card of result) {
      card.draggable = false;
      card.dataModel.selectable = false;
      card.clicked.disconnect(selectCard);
      card.selectedChanged.disconnect(adjustCards);
      // card.doubleClicked.disconnect(doubleClickCard);
      card.released.disconnect(updateCardReleased);
      card.startDrag.disconnect(updateCardDragging);
      card.dataModel.prohibitReason = "";
    }
    return result;
  }

  function updateCardPosition(animated) {
    cardArea.updateCardPosition(false);

    cards.forEach(card => {
      if (card.selected) {
        card.origY -= 20;
      }
      if (!card.selectable && Config.hideUseless) {
        card.origY += 60;
      }
    });

    if (animated) {
      cards.forEach(card => {
        if (!card.dragging) card.goBack(true);
      });
    }
  }

  function updateCardDragging(_card) {
    if (!_card) return;
    _card.goBackAnim.stop();
    _card.opacity = 0.8

    if (Config.enableSuperDrag) {
      draggingCard = _card;
      draggingClickedPhoto = null;
      _card.xChanged.connect(dragMovement);
      _card.yChanged.connect(dragMovement);
    }
  }

  function dragMovement() {
    if (!Config.enableSuperDrag) return;
    const card = draggingCard;
    if (!card) return;
    const x = card.x + card.dragCenter.x;
    const y = card.y + card.dragCenter.y;
    if (y >= roomScene.dashboard.y && x <= roomScene.getPhoto(Cpp.self.id).x) {
      return;
    }
    if (!card.selectable) return;

    if (!card.selected) {
      cardSelected(card.cid, true);
    }

    let belowPhoto;
    for (const player of Lua.client.players) {
      const photo = roomScene.getPhoto(player.id);
      const actualW = photo.width * photo.scale;
      const actualH = photo.height * photo.scale;
      const actualX = photo.x + (photo.width - actualW) / 2;
      const actualY = photo.y + (photo.height - actualH) / 2;

      if (x >= actualX && x <= actualX + actualW && y >= actualY && y <= actualY + actualH) {
        belowPhoto = photo;
        if (draggingClickedPhoto === photo) continue;
        draggingClickedPhoto = photo;
        photo.selected = photo.selectable ? !photo.selected : false;
      }
    }

    if (!belowPhoto) draggingClickedPhoto = null;
  }

  function updateCardReleased(_card) {
    let i;
    let c;
    let index;

    const inDragUse = (Config.enableSuperDrag && _card === draggingCard);
    draggingCard = null;
    draggingClickedPhoto = null;
    _card.xChanged.disconnect(dragMovement);
    _card.yChanged.disconnect(dragMovement);

    if (inDragUse) {
      const x = _card.x + _card.dragCenter.x;
      const y = _card.y + _card.dragCenter.y;
      if ((y < roomScene.dashboard.y || x > roomScene.getPhoto(Cpp.self.id).x) && roomScene.okButton.enabled) {
        roomScene.okButton.clicked();
        return;
      } else if (_card.selected) {
        cardSelected(_card.cid, false);
      }
    }

    let card;
    movepos = null;
    for (let i = 0; i < cards.length; i++) {
      card = cards[i];
      if (card.dragging) continue;

      if (card.x > _card.x) {
        movepos = i - (index < i ? 1 : 0);
        break;
      }
    }
    if (movepos == null) { // 最右
      movepos = cards.length;
    }

    if (sortable && movepos != null) {
      const self = Lua.selfPlayer;
      const room = Lua.client;
      const handcardnum = self.getCardIds("h").length; // 不计入expand_pile
      const isMyHandcard = room.getCardArea(_card.cid) == Ltk.Card.PlayerHand &&
        room.getCardOwner(_card.cid).id == Cpp.self.id;
      if (isMyHandcard) {
        if (movepos >= handcardnum) movepos = handcardnum - 1;
      } else {
        if (movepos < handcardnum) movepos = handcardnum;
      }
      i = cards.indexOf(_card);
      cards.splice(i, 1);
      cards.splice(movepos, 0, _card);
      movepos = null;
    }
    updateCardPosition(true);
  }

  function adjustCards() {
    updateCardPosition(true);
  }

  function selectCard(card) {
    if (card.selectable) cardSelected(card.dataModel.cardId, card.selected);
    adjustCards();
  }

  function doubleClickCard(card) {
    if (Config.doubleClickUse) {
      Ltk.updateRequestUI("CardItem", card.dataModel.cardId, "doubleClick", { selected: card.selected, doubleClickUse: Config.doubleClickUse, autoTarget: Config.autoTarget } );
    }
  }

  function enableCards(cardIds) {
    let card, i;
    cards.forEach(card => {
      card.dataModel.selectable = cardIds.includes(card.cid);
      if (!card.dataModel.selectable) {
        card.selected = false;
      }
    });
    updateCardPosition(true);
  }

  function unselectAll() {
    for (let i = 0; i < cards.length; i++) {
      const card = cards[i];
      card.selected = false;
    }
    updateCardPosition(true);
  }

  function syncCards() {
    // sync expandedCards
    const allCards = [...dataModel.handcards, ...dataModel.expandedCards];
    const orderedCards = [];
    const extractedCards = [];
    for (const card of cards) {
      const idx = allCards.findIndex(e => e === card.dataModel);
      if (idx !== -1) {
        orderedCards[idx] = card;
      } else {
        extractedCards.push(card.dataModel);
      }
    }

    const myPos = roomScene.mapFromItem(root, 0, 0);
    for (const card of remove(extractedCards)) {
      cards.splice(cards.indexOf(card), 1);
      card.origX = myPos.x + width;
      card.origY = myPos.y;
      card.destroyOnStop();
      card.goBack(true);
    }

    cards = orderedCards;
    const component = Qt.createComponent("LunarLtk.Components", "CardItem");
    for (const model of allCards) {
      if (cards.find(e => e.dataModel === model)) continue;
      const card = component.createObject(roomScene, {
        x: myPos.x + width,
        y: myPos.y,
        dataModel: model,
      });
      const selectable = model.selectable;
      add(card);
      model.selectable = selectable;
    }

    updateCardPosition(true);
  }

  function applyChange(uiUpdate) {
    sortable = Ltk.canSortHandcards(Cpp.self.id);

    syncCards();
  }
}
