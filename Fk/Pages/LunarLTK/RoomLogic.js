// SPDX-License-Identifier: GPL-3.0-or-later

let callbacks={}

function arrangeManyPhotos() {
  /* Layout of photos:
   * +----------------+
   * |    -2 ... 2    |
   * | -1           1 |
   * |              0 |
   * +----------------+
   */

  const playerNum = roomScene.dataModel.playerNum;
  const photoBaseWidth = 175 * 0.75;
  const photoMaxWidth = 175 * 0.75;
  // const verticalSpacing = 32;
  const verticalSpacing = roomArea.height * 0.08;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = 16;

  let horizontalSpacing = 8;
  let photoWidth = (roomArea.width - horizontalSpacing * playerNum)
                 / (playerNum - 1);
  let photoScale = 1;
  if (photoWidth > photoMaxWidth) {
    photoWidth = photoMaxWidth;
    horizontalSpacing = (roomArea.width - photoWidth * (playerNum - 1))
                      / playerNum;
  } else {
    photoScale = photoWidth / photoBaseWidth;
  }

  const horizontalPadding = (photoWidth - photoBaseWidth) / 2;
  const startX = horizontalPadding + horizontalSpacing;
  const padding = photoWidth + horizontalSpacing;
  let regions = [
    {
      x: startX + padding * (playerNum - 2),
      y: roomScene.height - 192,
      scale: photoScale
    },
  ];
  let i;
  for (i = 0; i < playerNum - 1; i++) {
    regions.push({
      x: startX + padding * (playerNum - 2 - i),
      y: roomAreaPadding,
      scale: photoScale,
    });
  }
  regions[1].y += verticalSpacing * 3;
  regions[regions.length - 1].y += verticalSpacing * 3;
  regions[2].y += verticalSpacing;
  regions[regions.length - 2].y += verticalSpacing;

  let item, region;

  for (i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[photoModel[i].index];
    item.x = region.x;
    item.y = region.y;
    item.scale = region.scale;
  }
}

function arrangePhotos() {
  const playerNum = roomScene.dataModel.playerNum;
  if (playerNum > 8) {
    return arrangeManyPhotos();
  }

  /* Layout of photos:
   * +---------------+
   * |   6 5 4 3 2   |
   * | 7           1 |
   * |             0 |
   * +---------------+
   */

  const photoWidth = 175 * 0.75;
  // Padding is negative, because photos are scaled.
  const roomAreaPadding = 16;
  const verticalPadding = 0;
  const verticalSpacing = roomArea.height * 0.08;
  const horizontalSpacing = (roomArea.width - photoWidth * 7) / 8;

  // Position 1-7
  const startX = verticalPadding + horizontalSpacing;
  const padding = photoWidth + horizontalSpacing;
  const regions = [
    { x: startX + padding * 6, y: roomScene.height - 192 },
    { x: startX + padding * 6, y: roomAreaPadding + verticalSpacing * 3 },
    { x: startX + padding * 5, y: roomAreaPadding + verticalSpacing },
    { x: startX + padding * 4, y: roomAreaPadding },
    { x: startX + padding * 3, y: roomAreaPadding },
    { x: startX + padding * 2, y: roomAreaPadding },
    { x: startX + padding, y: roomAreaPadding + verticalSpacing },
    { x: startX, y: roomAreaPadding + verticalSpacing * 3 },
  ];

  const regularSeatIndex = [
    [0],
    [0, 4],
    [0, 3, 5],
    [0, 1, 4, 7],
    [0, 1, 3, 5, 7],
    [0, 1, 3, 4, 5, 7],
    [0, 1, 2, 3, 5, 6, 7],
    [0, 1, 2, 3, 4, 5, 6, 7],
  ];
  const seatIndex = regularSeatIndex[playerNum - 1];

  let item, region, i;

  for (i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    if (!item)
      continue;

    region = regions[seatIndex[photoModel[i].index]];
    item.x = region.x;
    item.y = region.y;
  }
}

function replyToServer(jsonData) {
  ClientInstance.replyToServer("", jsonData);
  roomScene.state = "notactive";
}

function getPhoto(id) {
  return dataModel.getPhoto(id)?.photoItem;
}

function getAreaItem(area, id) {
  const publicArea = roomScene.getAreaItem(area);
  if (publicArea) return publicArea;

  const photo = getPhoto(id);
  if (!photo) {
    return null;
  }

  if (area === Ltk.Card.PlayerHand && id === Self.id) {
    return dashboard.handcardArea;
  }

  return photo.getAreaItem(area);
}

function moveCards(data) {
  const moves = data.merged;
  for (let i = 0; i < moves.length; i++) {
    const move = moves[i];
    const from = getAreaItem(move.fromArea, move.from);
    const to = getAreaItem(move.toArea, move.to);
    if (!from || !to || (from === to && from !== tablePile) || (from === tablePile && move.toArea === Ltk.Card.DiscardPile))
      continue;
    const items = from.remove(move.ids, move.fromSpecialName, data);
    items.forEach((item) => item.known = !!data[item.cid.toString()]); // updata card visible. must be before move animation
    if (to === tablePile) {
      items.forEach((item) => item.holding_event_id = data.event_id);
      let vanished = items.filter(c => c.cid === -1);
      if (vanished.length > 0) {
        drawPile.add(vanished, move.specialName);
        drawPile.updateCardPosition(true);
      }
      vanished = items.filter(c => c.cid !== -1);
      if (vanished.length > 0) {
        to.add(vanished, move.specialName);
        to.updateCardPosition(true);
      }
    } else {
      if (items.length > 0)
        to.add(items, move.specialName);
      to.updateCardPosition(true);
    }
  }
}

const suitInteger = {
  spade: 1, heart: 3,
  club: 2, diamond: 4,
}

function sortHandcards(sortMethods) {
  if (!dashboard.handcardArea.cards.length) {
    return;
  }

  const cardType = sortMethods[0];
  const cardNum = sortMethods[1];
  const cardSuit = sortMethods[2];

  if (!cardType && !cardNum && !cardSuit) {
    return;
  }

  let sortOutputs = [];
  let sortedStatus = [];

  const subtypeString2Number = {
    ["none"]: Ltk.Card.SubtypeNone,
    ["delayed_trick"]: Ltk.Card.SubtypeDelayedTrick,
    ["weapon"]: Ltk.Card.SubtypeWeapon,
    ["armor"]: Ltk.Card.SubtypeArmor,
    ["defensive_ride"]: Ltk.Card.SubtypeDefensiveRide,
    ["offensive_ride"]: Ltk.Card.SubtypeOffensiveRide,
    ["treasure"]: Ltk.Card.SubtypeTreasure,
  }

  const others = [];
  const hands = [];
  const orignal_hands = Ltk.getPlayerHandcards(Self.id); // 不计入expand_pile

  dashboard.handcardArea.cards.forEach(c => {
    if (orignal_hands.includes(c.cid)) {
      hands.push(c);
    } else {
      others.push(c);
    }
  })

  const orignal = hands.map(c => {
    return c.cid;
  })


  let sortedByType = true;
  let handcards
  if (cardType) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
        if (prev.type === next.type) {
          const prevSubtypeNumber = subtypeString2Number[prev.subtype];
          const nextSubtypeNumber = subtypeString2Number[next.subtype];
          if (prevSubtypeNumber === nextSubtypeNumber) {
            const splitedPrevName = prev.name.split('__');
            const prevTrueName = splitedPrevName[splitedPrevName.length - 1];

            const splitedNextName = next.name.split('__');
            const nextTrueName = splitedNextName[splitedNextName.length - 1];
            if (prevTrueName === nextTrueName) {
              return prev.cid - next.cid;
            } else {
              return prevTrueName > nextTrueName ? -1 : 1;
            }
          } else {
            return prevSubtypeNumber - nextSubtypeNumber;
          }
        } else {
          return prev.type - next.type;
        }
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    // Check if the cards are sorted by type
    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedByType = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedByType);
  }

  let sortedByNum = true;
  if (cardNum) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
        if (prev.number === next.number) {
          if (prev.suit === next.suit) {
            return prev.cid - next.cid;
          } else {
            return suitInteger[prev.suit] - suitInteger[next.suit];
          }
        } else {
          return prev.number - next.number;
        }
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedByNum = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedByNum);
  }

  let sortedBySuit = true;
  if (cardSuit) {
    handcards = hands.slice(0);
    handcards.sort((prev, next) => {
      if (prev.footnote === next.footnote) {
        if (prev.suit === next.suit) {
          if (prev.number === next.number) {
            return prev.cid - next.cid;
          } else {
            return prev.number - next.number;
          }
        } else {
          return suitInteger[prev.suit] - suitInteger[next.suit];
        }
      } else {
        return prev.footnote > next.footnote ? 1 : -1;
      }
    });

    let i = 0;
    handcards.every(c => {
      if (orignal[i] !== c.cid) {
        sortedBySuit = false;
        return false;
      }
      i++;
      return true;
    })
    sortOutputs.push(handcards);
    sortedStatus.push(sortedBySuit);
  }
  let output
  for (let i = 0; i < sortedStatus.length; i++) {
    if (sortedStatus[i]) {
      let j = i < sortedStatus.length - 1 ? i + 1 : 0;
      output = sortOutputs[j];
      break;
    }
  }
  if (!output) output = sortOutputs[0];
  others.forEach(c => {
    output.push(c);
  });
  dashboard.handcardArea.cards = output;
  dashboard.handcardArea.updateCardPosition(true);
}

function setEmotion(id, emotion, isCardId) {
  let path;
  if (OS === "Win") {
    // Windows: file:///C:/xxx/xxxx
    path = (SkinBank.pixAnimDir + emotion).replace("file:///", "");
  } else {
    path = (SkinBank.pixAnimDir + emotion).replace("file://", "");
  }

  if (!Backend.exists(path)) {
    // Try absolute path again
    if (OS === "Win") {
      // Windows: file:///C:/xxx/xxxx
      path = (AppPath + "/" + emotion).replace("file:///", "");
    } else {
      path = (AppPath + "/" + emotion).replace("file://", "");
    }
    if (!Backend.exists(path))
      return;
  }
  if (!Backend.isDir(path)) {
    // TODO: set picture emotion
    return;
  }
  const component = Qt.createComponent("Fk.Components.LunarLTK", "PixmapAnimation");
  if (component.status !== Component.Ready)
    return;

  let photo;
  if (isCardId === true) {
    roomScene.tableCards.forEach((v) => {
      if (v.cid === id) {
        photo = v;
        return;
      }
    })
    if (!photo)
      return;
  } else {
    photo = getPhoto(id);
    if (!photo) {
      return null;
    }
  }

  const animation = component.createObject(photo, {
    source: (OS === "Win" ? "file:///" : "") + path,
    scale: 0.75,
  });
  animation.anchors.centerIn = photo;
  if (isCardId) {
    animation.started.connect(() => photo.busy = true);
    animation.finished.connect(() => {
      photo.busy = false;
      animation.destroy()
    });
  } else {
    animation.finished.connect(() => animation.destroy());
  }
  animation.start();
}

function setCardFootnote(id, footnote, virtual) {
  let card;
  roomScene.tableCards.forEach((v) => {
    if ((virtual? v.virt_id : v.cid) === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    return;
  }

  card.footnote = footnote;
  card.footnoteVisible = true;
}

callbacks["SetCardFootnote"] = (sender, data) => {
  const [id, note, virtual] = data;
  setCardFootnote(id, note, virtual);
}

function setCardVirtName(id, name, virtual) {
  let card;
  roomScene.tableCards.forEach((v) => {
    if ((virtual? v.virt_id : v.cid) === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    return;
  }

  card.virt_name = name;
}

callbacks["SetCardVirtName"] = (sender, data) => {
  const [ids, note, virtual] = data;
  ids.forEach(id => setCardVirtName(id, note, virtual));
}

callbacks["ShowVirtualCard"] = (sender, data) => {
  const [card_data, playerid, footnote, event_id] = data;
  let from = drawPile;
  const photo = getPhoto(playerid);
  if (photo) {
    from = (playerid === Self.id ? dashboard.handcardArea : photo.handcardArea);
  }

  const items = [];
  for (let i = 0; i < card_data.length; i++) {
    const dat = Lua.call("ToQml", card_data[i]);
    let component = Qt.createComponent(dat.uri, dat.name);
    let state = dat.prop;
    const parentPos = roomScene.mapFromItem(from, 0, 0);
    state.x = parentPos.x;
    state.y = parentPos.y;
    const card = component.createObject(roomScene.dynamicCardArea, state);
    card.x -= card.width / 2;
    card.y -= card.height / 2;
    card.holding_event_id = event_id;
    card.known = true;
    if (footnote) {
      card.footnote = footnote;
      card.footnoteVisible = true;
    }
    items.push(card);
  }

  tablePile.add(items);
  tablePile.updateCardPosition(true);
}

callbacks["DestroyTableCard"] = (sender, data) => {
  for (let i = 0; i < tablePile.cards.length; i++) {
    const card = tablePile.cards[i];
    if (data.indexOf(card.virt_id) !== -1) {
      //destroying the card immediately will cause animation errors
      card.holding_event_id = 0;
    }
  }
}

callbacks["DestroyTableCardByEvent"] = (sender, data) => {
  for (let i = 0; i < tablePile.cards.length; i++) {
    const card = tablePile.cards[i];
    if (card.holding_event_id >= data) {
      //destroying the card immediately will cause animation errors
      card.holding_event_id = 0;
    }
  }
}

function doIndicate(from, tos) {
  const component = Qt.createComponent("Fk.Components.LunarLTK", "IndicatorLine");
  if (component.status !== Component.Ready)
    return;

  const fromItem = getPhotoOrDashboard(from);
  const fromPos = mapFromItem(fromItem, fromItem.width / 2,
                              fromItem.height / 2);

  const end = [];
  for (let i = 0; i < tos.length; i++) {
    if (from === tos[i])
      continue;
    const toItem = getPhotoOrDashboard(tos[i]);
    const toPos = mapFromItem(toItem, toItem.width / 2, toItem.height / 2);
    end.push(toPos);
  }

  const color = "#96943D";
  const line = component.createObject(roomScene, {
                                        start: fromPos,
                                        end: end,
                                        color: color
                                      });
  line.finished.connect(() => line.destroy());
  line.running = true;
}

callbacks["UpdateHandcard"] = (sender) => {
  roomScene.dashboard.handcardArea.cards.forEach((v) => {
    const id = v.cid;
    if (Lua.evaluate(`ClientInstance:getCardArea(${id}) == Card.PlayerHand and ClientInstance:getCardOwner(${id}) == Self`)) {
      v.setData(Ltk.getCardData(id, true));
      v.known = Lua.selfPlayer.cardVisible(id);
      v.draggable = true;
    }
  });
}

callbacks["UpdateCard"] = (sender, j) => {
  const id = parseInt(j);
  let card;
  let filterCard = false;
  roomScene.tableCards.forEach((v) => {
    if (v.cid === id) {
      card = v;
      return;
    }
  });

  if (!card) {
    roomScene.dashboard.handcardArea.cards.forEach((v) => {
      if (v.cid === id) {
        card = v;
        filterCard = true;
        return;
      }
    });
  }

  if (!card) {
    return;
  }

  card.setData(Ltk.getCardData(id, filterCard));
}

callbacks["UpdateSkill"] = (sender, j) => {
  const sortable = Ltk.canSortHandcards(Self.id);
  dashboard.sortable = sortable;
  dashboard.handcardArea.sortable = sortable;
  const all_skills = [roomScene.dashboard.skillButtons, roomScene.dashboard.notActiveButtons];
  for (const skills of all_skills) {
    for (let i = 0; i < skills.count; i++) {
      const item = skills.itemAt(i);
      const p = Lua.selfPlayer;
      const skill = Ltk.getSkill(item.orig);
      item.locked = !skill.isEffectable(p);
      item.times = skill.getTimes(p);
    }
  }
}

callbacks["ArrangeSeats"] = (sender, order) => {
  // jsonData: seat order

  for (let i = 0; i < photoModel.length; i++) {
    const item = photoModel[i];
    item.seatNumber = order.indexOf(item.playerid) + 1;
  }

  // make Self to the first of list, then reorder photomodel
  const selfIndex = order.indexOf(Self.id);
  const after = order.splice(selfIndex);
  after.push(...order);
  const photoOrder = after;

  for (let i = 0; i < photoModel.length; i++) {
    const item = photoModel[i];
    item.index = photoOrder.indexOf(item.playerid);
  }

  arrangePhotos();
}

function cancelAllFocus() {
  let item;
  const playerNum = roomScene.dataModel.playerNum;
  for (let i = 0; i < playerNum; i++) {
    item = photos.itemAt(i);
    item.progressBar.visible = false;
    item.progressTip = "";
  }
}

callbacks["MoveFocus"] = (sender, data) => {
  // jsonData: int[] focuses, string command
  cancelAllFocus();
  const [ focuses, command ] = data;
  const timeout = data[2] ?? (Config.roomTimeout * 1000);

  let item, model;
  for (const pid of focuses) {
    const model = dataModel.getPhoto(pid);
    if (!model) continue;
    const item = model.photoItem;
    item.progressBar.duration = timeout;
    item.progressBar.visible = true;
    item.progressTip = Lua.tr(command)
      + Lua.tr(" thinking...");
  }
}

callbacks["PlayerRunned"] = (sender, data) => {
  // jsonData: int runner, int robot
  const [ runner, robot ] = data;

  const model = dataModel.getPhoto(runner);
  if (typeof(model) !== "undefined") {
    model.playerid = robot;
  }
}

callbacks["AskForGeneral"] = (sender, data) => {
  // jsonData: string[] generals, integer n, boolean no_convert, boolean heg, string rule, table extra_data
  const [ generals, n, no_convert, heg, rule, extra_data ] = data;

  roomScene.dataModel.setPrompt("#AskForGeneral");
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "ChooseGeneralBox");
  const box = roomScene.popupBox.item;
  box.accepted.connect(() => {
    replyToServer(box.choices);
  });
  box.generals = generals;
  box.choiceNum = n ?? 1;
  box.convertDisabled = !!no_convert;
  box.hegemony = !!heg;
  box.rule_type = rule ?? (heg? "heg_general_choose" : "askForGeneralsChosen"); // 若heg为true，默认应用国战选将
  box.extra_data = extra_data ?? { n : n };
  for (let i = 0; i < generals.length; i++)
    box.generalList.append({ "name": generals[i] });
  box.updatePosition();
  box.refreshPrompt();
}

callbacks["AskForSkillInvoke"] = (sender, data) => {
  // jsonData: [ string name, string prompt ]
  const [ skill, prompt ] = data;
  roomScene.dataModel.setPrompt(prompt || `#AskForSkillInvoke:::${skill}`);
  roomScene.activate();
}

callbacks["AskForArrangeCards"] = (sender, data) => {
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "ArrangeCardsBox");
  const box = roomScene.popupBox.item;
  const cards = data.cards;
  box.cards = cards.reduce((newArray, elem) => {
    return newArray.concat(elem.map(cid => Ltk.getCardData(cid)));
  }, []);
  box.org_cards = cards;
  box.prompt = data.prompt;
  box.size = data.size;
  box.areaCapacities = data.capacities;
  box.areaLimits = data.limits;
  box.free_arrange = data.is_free;
  box.areaNames = data.names;
  box.pattern = data.pattern;
  box.poxi_type = data.poxi_type;
  box.cancelable = data.cancelable;

  box.initializeCards();
}

callbacks["AskForGuanxing"] = (sender, data) => {
  const cards = data.cards;
  const min_top_cards = data.min_top_cards;
  const max_top_cards = data.max_top_cards;
  const min_bottom_cards = data.min_bottom_cards;
  const max_bottom_cards = data.max_bottom_cards;
  const top_area_name = data.top_area_name;
  const bottom_area_name = data.bottom_area_name;
  const prompt = data.prompt;
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "GuanxingBox");
  const box = roomScene.popupBox.item;
  box.prompt = prompt;
  box.free_arrange = data.is_free;
  if (max_top_cards === 0) {
    box.areaCapacities = [max_bottom_cards];
    box.areaLimits = [min_bottom_cards];
    box.areaNames = [Lua.tr(bottom_area_name)];
  } else {
    if (max_bottom_cards === 0) {
      box.areaCapacities = [max_top_cards];
      box.areaLimits = [min_top_cards];
      box.areaNames = [Lua.tr(top_area_name)];
    } else {
      box.areaCapacities = [max_top_cards, max_bottom_cards];
      box.areaLimits = [min_top_cards, min_bottom_cards];
      box.areaNames = [Lua.tr(top_area_name), Lua.tr(bottom_area_name)];
    }
  }
  box.org_cards = cards;
  box.cards = cards.reduce((newArray, elem) => {
    return newArray.concat(elem.map(cid => Ltk.getCardData(cid)));
  }, []);
  box.initializeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForExchange"] = (sender, data) => {
  const cards = [];
  const cards_name = [];
  const capacities = [];
  const limits = [];
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "GuanxingBox");
  let for_i = 0;
  const box = roomScene.popupBox.item;
  box.org_cards = data.piles;
  data.piles.forEach(ids => {
    if (ids.length > 0) {
      ids.forEach(id => cards.push(Ltk.getCardData(id)));
      capacities.push(ids.length);
      limits.push(0);
      cards_name.push(Lua.tr(data.piles_name[for_i]));
      for_i ++;
    }
  });
  box.cards = cards;
  box.areaCapacities = capacities
  box.areaLimits = limits
  box.areaNames = cards_name
  box.initializeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForChoice"] = (sender, data) => {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  const [ choices, all_choices, skill_name, prompt, detailed ] = data;

  roomScene.dataModel.setPrompt(prompt || `#AskForChoice:::${skill_name}`);
  roomScene.activate();
  let qmlSrc;
  if (!detailed) {
    qmlSrc = "ChoiceBox";
  } else {
    qmlSrc = "DetailedChoiceBox";
  }
  roomScene.popupBox.sourceComponent = Qt.createComponent("Fk.Pages.LunarLTK",qmlSrc);
  const box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.all_options = all_choices;
  box.accepted.connect(() => {
    replyToServer(all_choices[box.result]);
  });
}

callbacks["AskForChoices"] = (sender, data) => {
  // jsonData: [ string[] choices, string skill ]
  // TODO: multiple choices, e.g. benxi_ol
  const [ choices, all_choices, [ min_num, max_num], cancelable, skill_name, prompt, detailed ] = data;
  roomScene.dataModel.setPrompt(prompt || `#AskForChoice:::${skill_name}`);
  roomScene.activate();
  let qmlSrc;
  if (!detailed) {
    qmlSrc = "CheckBox";
  } else {
    qmlSrc = "DetailedCheckBox";
  }
  roomScene.popupBox.sourceComponent = Qt.createComponent("Fk.Pages.LunarLTK",qmlSrc);
  const box = roomScene.popupBox.item;
  box.options = choices;
  box.skill_name = skill_name;
  box.all_options = all_choices;
  box.min_num = min_num;
  box.max_num = max_num;
  box.cancelable = cancelable;
  box.accepted.connect(() => {
    const ret = [];
    box.result.forEach(id => {
      ret.push(all_choices[id]);
    });
    replyToServer(ret);
  });
}

callbacks["AskForCardChosen"] = (sender, data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  string reason ]
  const reason = data._reason;
  const prompt = data._prompt;
  roomScene.dataModel.setPrompt(prompt || `#AskForChooseCard:${data._id}::${reason}`);
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "PlayerCardBox");

  const box = roomScene.popupBox.item;
  box.prompt = prompt;
  box.visible_data = data.visible_data ?? {};
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => {
      let v = Ltk.getCardData(id);
      const vcard = Ltk.getVirtualEquipData(data._id, id);
      if (vcard) {
        v.virt_name = vcard.name;
      }
      arr.push(v);
    });
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardSelected.connect(cid => replyToServer(cid));
}

callbacks["AskForCardsChosen"] = (sender, data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const min = data._min;
  const max = data._max;
  const reason = data._reason;
  const prompt = data._prompt;

  roomScene.dataModel.setPrompt(prompt || `#AskForChooseCards:${data._id}::${reason}:${min}:${max}`);
  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "PlayerCardBox");
  const box = roomScene.popupBox.item;
  box.multiChoose = true;
  box.min = min;
  box.max = max;
  box.prompt = prompt;
  box.visible_data = data.visible_data ?? {};
  for (let d of data.card_data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => arr.push(Ltk.getCardData(id)));
    box.addCustomCards(d[0], arr);
  }

  roomScene.popupBox.moveToCenter();
  box.cardsSelected.connect((ids) => {
    replyToServer(ids);
  });
}

callbacks["AskForPoxi"] = (sender, dat) => {
  const { type, data, extra_data, cancelable } = dat;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "PoxiBox");
  const box = roomScene.popupBox.item;
  box.extra_data = extra_data;
  box.poxi_type = type;
  box.card_data = data;
  box.cancelable = cancelable;
  for (let d of data) {
    const arr = [];
    const ids = d[1];

    ids.forEach(id => arr.push(Ltk.getCardData(id)));
    box.addCustomCards(d[0], arr);
  }
  box.refreshPrompt();

  roomScene.popupBox.moveToCenter();
  box.cardsSelected.connect((ids) => {
    replyToServer(ids);
  });
}

callbacks["AskForMoveCardInBoard"] = (sender, data) => {
  const { cards, cardsPosition, generalNames, playerIds } = data;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "MoveCardInBoardBox");

  const boxCards = [];
  cards.forEach(id => {
    const cardPos = cardsPosition[cards.findIndex(cid => cid === id)];
    let d = Ltk.getCardData(id);
    const vcard = Ltk.getVirtualEquipData(playerIds[cardPos], id);
    if (vcard) {
      d.virt_name = vcard.name;
    }
    boxCards.push(d);
  });

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.cardsPosition = cardsPosition;
  box.playerIds = playerIds;
  box.generalNames = generalNames.map(name => {
    const namesSplit = name.split('/');
    if (namesSplit.length > 1) {
      return namesSplit.map(nameSplit => Lua.tr(nameSplit)).join('/');
    }
    return Lua.tr(name);
  });

  box.arrangeCards();
  box.accepted.connect(() => {
    replyToServer(box.getResult());
  });
}

callbacks["AskForCardsAndChoice"] = (sender, data) => {
  // jsonData: [ int[] handcards, int[] equips, int[] delayedtricks,
  //  int min, int max, string reason ]
  const { cards, choices, prompt, cancel_choices, min, max, filter_skel, disabled, extra_data } = data;

  roomScene.activate();
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "ChooseCardsAndChoiceBox");

  const boxCards = [];
  cards.forEach(id => boxCards.push(Ltk.getCardData(id)));

  const box = roomScene.popupBox.item;
  box.cards = boxCards;
  box.ok_options = choices;
  box.prompt = prompt ?? "";
  box.cancel_options = cancel_choices ?? [];
  box.min = min ?? 1;
  box.max = max ?? 1;
  box.disable_cards = disabled ?? [];
  box.filter_skel = filter_skel ?? "";
  box.extra_data = extra_data;

  roomScene.popupBox.moveToCenter();
}

callbacks["MoveCards"] = (sender, moves) => {
  // jsonData: merged moves
  moveCards(moves);
}

// 切换状态 -> 向Lua询问UI情况
// 所以Lua一开始就要设置好各种亮灭的值 而这个自然是通过update
callbacks["PlayCard"] = () => {
  roomScene.activate();
  roomScene.okCancel.visible = true;
}

callbacks["LoseSkill"] = (sender, data) => {
  // jsonData: [ int player_id, string skill_name ]
  const [ id, skill_name, prelight ] = data;
  if (id === Self.id) {
    dashboard.loseSkill(skill_name, prelight);
  }
}

callbacks["AddSkill"] = (sender, data) => {
  // jsonData: [ int player_id, string skill_name ]
  const [ id, skill_name, prelight ] = data;
  if (id === Self.id) {
    dashboard.addSkill(skill_name, prelight);
  }
}

callbacks["PrelightSkill"] = (sender, data) => {
  const [ skill_name, prelight ] = data;

  dashboard.prelightSkill(skill_name, prelight);
}

callbacks["AskForUseActiveSkill"] = (sender, data) => {
  // jsonData: string skill_name, string prompt
  const [ skill_name, prompt, cancelable ] = data;
  const extra_data = data[3] ?? {};
  roomScene.dataModel.setPrompt(prompt || `#AskForUseActiveSkill:::${skill_name}`);
  roomScene.activate();
  roomScene.okCancel.visible = true;
}

callbacks["CancelRequest"] = () => {
  roomScene.state = "notactive";
}

callbacks["AskForUseCard"] = (sender, data) => {
  // jsonData: card, pattern, prompt, cancelable, {}
  const [ cardname, pattern, prompt, cancelable, extra_data, disabledSkillNames ] = data;

  roomScene.dataModel.setPrompt(prompt || `#AskForUseCard:::${cardname}`);
  roomScene.activate();
  roomScene.okCancel.visible = true;
  if (extra_data != null) {
    if ((extra_data.effectTo !== Self.id && // 忽略本轮无懈可击，但目标是自己时不忽略
        roomScene.skippedUseEventId.find(id => id === extra_data.useEventId)) ||
        (Config.noSelfNullification && extra_data.effectFrom === Self.id &&
        !Ltk.getCardData(extra_data.effectCardId).multiple_targets)) { // 不对自己使用的单目标锦囊牌无懈
      Ltk.updateRequestUI("Button", "Cancel");
      return;
    } else {
      roomScene.extra_data = extra_data;
    }
  }
}

callbacks["AskForResponseCard"] = (sender, data) => {
  // jsonData: card_name, pattern, prompt, cancelable, {}
  const [ cardname, pattern, prompt, cancelable, extra_data, disabledSkillNames ] = data;

  roomScene.dataModel.setPrompt(prompt || `#AskForResponseCard:::${cardname}`);
  roomScene.activate();
  roomScene.okCancel.visible = true;
}

callbacks["Animate"] = (sender, data) => {
  // jsonData: [Object object]
  switch (data.type) {
    case "Indicate":
      data.to.forEach(item => {
        doIndicate(data.from, [item[0]]);
        if (item[1]) {
          doIndicate(item[0], item.slice(1));
        }
      })
      break;
    case "Emotion":
      setEmotion(data.player, data.emotion, data.is_card);
      break;
    case "LightBox":
      break;
    case "SuperLightBox": {
      const path = data.path;
      const jsonData = data.data;
      roomScene.bigAnim.source = AppPath + "/" + path;
      if (jsonData && jsonData !== "") {
        roomScene.bigAnim.item.loadData(jsonData);
      }
      break;
    }
    case "InvokeSkill": {
      const id = data.player;
      const component =
            Qt.createComponent("Fk.Components.LunarLTK", "SkillInvokeAnimation");
      if (component.status !== Component.Ready)
        return;

      const photo = getPhoto(id);
      if (!photo) {
        return null;
      }

      const animation = component.createObject(photo, {
        skill_name: Lua.tr(data.name),
        skill_type: (data.skill_type ? data.skill_type : "special"),
      });
      animation.anchors.centerIn = photo;
      animation.finished.connect(() => animation.destroy());
      break;
    }
    case "InvokeUltSkill": {
      const id = data.player;
      const photo = getPhoto(id);
      if (!photo) {
        return null;
      }

      roomScene.bigAnim.sourceComponent = Qt.createComponent("Fk.Components.LunarLTK", "UltSkillAnimation");
      roomScene.bigAnim.item.loadData({
        skill_name: data.name,
        general: data.deputy ? photo.deputyGeneral : photo.general,
      });
      break;
    }
    default:
      break;
  }
}

callbacks["LogEvent"] = (sender, data) => {
  // jsonData: [Object object]
  switch (data.type) {
    case "Damage": {
      const item = getPhotoOrDashboard(data.to);
      setEmotion(data.to, "damage");
      item.tremble();
      data.damageType = data.damageType || "normal_damage";
      Backend.playSound("./audio/system/" + data.damageType +
                        (data.damageNum > 1 ? "2" : ""));
      break;
    }
    case "LoseHP": {
      Backend.playSound("./audio/system/losehp");
      break;
    }
    case "ChangeMaxHp": {
      if (data.num < 0) {
        Backend.playSound("./audio/system/losemaxhp");
      }
      break;
    }
    case "PlaySkillSound": {
      const skill = data.name;
      // let extension = data.extension;
      let extension;
      let path;
      let dat;
      const tryPlaySound = (general) => {
        if (general) {
          const dat = Ltk.getGeneralData(general);
          const extension = dat.extension;
          const path = SkinBank.getAudio(skill + "_" + general, extension, "skill");
          if (path !== undefined) {
            Backend.playSound(path, data.i);
            return true;
          }
        }
        return false;
      };

      // Try main general first, then deputy general
      if (tryPlaySound(data.general) || tryPlaySound(data.deputy)) {
        break;
      }

      // finally normal skill
      dat = Ltk.getSkillData(skill);
      extension = dat.extension;
      path = SkinBank.getAudio(skill, extension, "skill");
      Backend.playSound(path, data.i);
      break;
    }
    case "PlaySound": {
      const path = SkinBank.getAudioByPath(data.name);
      Backend.playSound(path);
      break;
    }
    case "Death": {
      const item = getPhoto(data.to);
      const extension = Ltk.getGeneralData(item.general).extension;
      const path = SkinBank.getAudio(item.general, extension, "death");
      Backend.playSound(path);
      break;
    }
    default:
      break;
  }
}

callbacks["GameOver"] = (sender, jsonData) => {
  roomScene.state = "notactive";
  roomScene.popupBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "GameOverBox");
  const box = roomScene.popupBox.item;
  box.winner = jsonData;
  // roomScene.isStarted = false;
}

callbacks["FillAG"] = (sender, data) => {
  const ids = data[0];
  roomScene.manualBox.sourceComponent =
    Qt.createComponent("Fk.Pages.LunarLTK", "AG");
  roomScene.manualBox.item.addIds(ids);
}

callbacks["AskForAG"] = (sender, j) => {
  roomScene.activate();
  roomScene.manualBox.item.interactive = true;
}

callbacks["TakeAG"] = (sender, data) => {
  if (!roomScene.manualBox.item) return;
  const pid = data[0];
  const cid = data[1];
  const item = getPhoto(pid);
  const general = Lua.tr(item.general);

  // the item should be AG box
  roomScene.manualBox.item.takeAG(general, cid);
}

callbacks["CloseAG"] = () => roomScene.manualBox.item.close();

callbacks["CustomDialog"] = (sender, data) => {
  const path = data.path;
  const dat = data.data;
  roomScene.activate();
  roomScene.popupBox.source = AppPath + "/" + path;
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["MiniGame"] = (sender, data) => {
  const game = data.type;
  const dat = data.data;
  const gdata = Ltk.getMiniGame(game, Self.id, JSON.stringify(dat));
  roomScene.activate();
  roomScene.popupBox.source = AppPath + "/" + gdata.qml_path + ".qml";
  if (dat) {
    roomScene.popupBox.item.loadData(dat);
  }
}

callbacks["UpdateMiniGame"] = (sender, data) => {
  if (roomScene.popupBox.item) {
    roomScene.popupBox.item.updateData(data);
  }
}

callbacks["EmptyRequest"] = (sender, data) => {
  roomScene.activate();
}

callbacks["UpdateDrawPile"] = (sender, j) => {
  const data = parseInt(j);
  roomScene.dataModel.drawPileNum = data;
}

callbacks["UpdateRoundNum"] = (sender, j) => {
  const data = parseInt(j);
  roomScene.dataModel.roundCount = data;
}

callbacks["ChangeSkin"] = (sender, data) => {
  const photo = getPhoto(Number(data[0]));
  const path = data[2];
  const deputypath = data[3];
  if (path) {
    if (Number(data[0]) === Self.id) {
      Config.enabledSkins[photo.general] = path === "-" ? "" : path;
    }
    photo.skinSource = path === "-" ? "" : (AppPath + "/" + path);
  }
  if (deputypath) {
    if (Number(data[0]) === Self.id) {
      Config.enabledSkins[photo.deputyGeneral] = deputypath === "-" ? "" : deputypath;
    }
    photo.deputySkinSource = deputypath === "-" ? "" : (AppPath + "/" + deputypath);
  }
  photo.changeSkinTimer.start()
}

// 神貂蝉
callbacks["ChangeSelf"] = (sender, j) => {
  // move new selfPhoto to dashboard
  let order = new Array(photoModel.length);
  for (let i = 0; i < photoModel.length; i++) {
    const item = photoModel[i];
    order[item.seatNumber - 1] = item.playerid;
    if (item.playerid === Self.id) {
      dashboard.self = photos.itemAt(i);
    }
  }
  callbacks["ArrangeSeats"](null, order);

  // update dashboard
  dashboard.update();
}

callbacks["UpdateRequestUI"] = (sender, uiUpdate) => {
  if (uiUpdate["_prompt"])
    roomScene.dataModel.setPrompt(uiUpdate["_prompt"]);

  if (uiUpdate._type == "Room") {
    roomScene.applyChange(uiUpdate);
  }
}

// 蒋琬
callbacks["GetPlayerHandcards"] = (sender, data) => {
  const hand = dashboard.handcardArea.cards.map(c => {
    return c.cid;
  })
  replyToServer(hand);
}

callbacks["ReplyToServer"] = (sender, data) => {
  replyToServer(data);
}

