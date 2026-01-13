import QtQuick
import Fk
import LunarLtk.Components

QtObject {
  id: root

  property list<CardModel> handcards: [];

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
}
