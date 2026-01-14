import QtQuick
import Fk
import LunarLtk

QtObject {
  id: root

  property list<CardModel> handcards: [];
  property list<CardModel> expandedCards: [];

  property list<SkillModel> skills: [];
  property list<SkillModel> fakeSkills: [];

  signal handcardsSorted()

  function sortHandcards(sortMethod) {
    const typeSorter = (a, b) => {
      if (a.type !== b.type) return a.type - b.type;
      if (a.subtype !== b.subtype) {
        const subtypeInt = {
          ["none"]: Ltk.Card.SubtypeNone,
          ["delayed_trick"]: Ltk.Card.SubtypeDelayedTrick,
          ["weapon"]: Ltk.Card.SubtypeWeapon,
          ["armor"]: Ltk.Card.SubtypeArmor,
          ["defensive_ride"]: Ltk.Card.SubtypeDefensiveRide,
          ["offensive_ride"]: Ltk.Card.SubtypeOffensiveRide,
          ["treasure"]: Ltk.Card.SubtypeTreasure,
        }
        return subtypeInt[a.subtype] - subtypeInt[b.subtype];
      }
      if (a.name !== b.name) {
        return a.name.localeCompare(b.name);
      }
      return a.cardId - b.cardId;
    };

    const numberSorter = (a, b) => {
      if (a.number !== b.number) return a.number - b.number;
      return a.cardId - b.cardId;
    };

    const suitSorter = (a, b) => {
      const suitInt = {
        spade: 1, heart: 3,
        club: 2, diamond: 4,
      }
      if (a.suit !== b.suit) return suitInt[a.suit] - suitInt[b.suit];
      return a.cardId - b.cardId;
    };

    // sortMethod: 0=type, 1=number, 2=suit
    if (sortMethod === 0) {
      handcards.sort(typeSorter);
    } else if (sortMethod === 1) {
      handcards.sort(numberSorter);
    } else if (sortMethod === 2) {
      handcards.sort(suitSorter);
    }

    handcardsSorted();
  }

  function addSkill(skill_name, prelight) {
    const model = Ltk.createSkillModel(skill_name);
    const arr = prelight ? fakeSkills : skills;

    if (!arr.find(e => e.origName === skill_name)) {
      arr.push(model);
      if (arr === fakeSkills) {
        model.selectedChanged.connect(() => {
          if (!model.selected) return;
          model.enabled = false;
          ClientInstance.notifyServer("PushRequest", [
            "prelight", model.origName, (!model.prelighted).toString()
          ].join(","));
        });
      } else {
        model.selectedChanged.connect(() => {
          if (model.enabled) roomScene.activateSkill(model.origName, model.selected, "click");
        });
      }
    }
    return;
  }

  function loseSkill(skill_name, prelight) {
    const arr = prelight ? fakeSkills : skills;
    const idx = arr.findIndex(e => e.origName === skill_name);
    if (idx !== -1) arr.splice(idx, 1);
  }

  function disableAllSkills() {
    for (const model of skills) {
      model.enabled = false;
    }
  }

  function changeSelf() {
    const self = Lua.selfPlayer;
    const ids = self.getCardIds("h");
    handcards = ids.map(id => Ltk.createCardModel(id, { known: self.cardVisible(cid) }));
    expandedCards = [];

    skills = [];
    fakeSkills = [];
    for (const s of self.player_skills) {
      addSkill(s.name);
    }
  }

  function refreshData() {
    // const sortable = Ltk.canSortHandcards(Cpp.self.id);
    // dashboard.sortable = sortable;
    // dashboard.handcardArea.sortable = sortable;
    const p = Lua.selfPlayer;
    for (const model of skills) {
      const skill = Ltk.getSkill(model.origName);
      model.nullified = !skill.isEffectable(p);
      model.times = skill.getTimes(p);
    }
  }

  function applyChange(uiUpdate) {
    uiUpdate["_delete"]?.forEach(data => {
      if (data.type !== "CardItem") return;
      const idx = expandedCards.findIndex(e => e.cardId === data.id);
      if (idx !== -1) expandedCards.splice(idx, 1);
    });

    uiUpdate["_new"]?.forEach(dat => {
      if (dat.type !== "CardItem") return;
      const card = Ltk.createCardModel(dat.data.id);
      card.footnote = Lua.tr(dat.ui_data.footnote);
      card.footnoteVisible = true;
      const vcard = Ltk.getVirtualEquipData(0, dat.data.id);
      if (vcard) card.virtName = vcard.name;
      expandedCards.push(card);
    });

    uiUpdate["CardItem"]?.forEach(cdata => {
      const card = handcards.find(e => e.cardId === cdata.id) ||
        expandedCards.find(e => e.cardId === cdata.id);

      if (card) {
        card.selectable = cdata.enabled;
        card.selected = cdata.selected;
      }
    });

    for (const card of handcards) {
      if (!card.selectable) {
        card.prohibitReason = Ltk.getCardProhibitReason(card.cardId);
      }
    }

    uiUpdate["SkillButton"]?.forEach(skdata => {
      const skillBtn = skills.find(e => e.origName === skdata.id);
      if (skillBtn) {
        skillBtn.enabled = skdata.enabled;
        skillBtn.selected = skdata.selected;
      }
    });
  }
}
