//
//  Arkham_ProxiesTests.swift
//  Arkham ProxiesTests
//
//  Created by Erik Oliver on 3/9/25.
//

import Testing
import Foundation
@testable import Arkham_Proxies

@MainActor
struct Arkham_ProxiesTests {

    @Test func manuallyAddedCardPreservesLeadingZeroAndQuantity() {
        let model = DeckViewModel()
        #expect(model.addCard(cardID: " 06113 ", quantity: " 2 "))
        #expect(model.cards.count == 1)
        #expect(model.cards.first?.cardID == "06113")
        #expect(model.cards.first?.quantity == 2)
        #expect(model.selectedCards.count == 1)
    }

    @Test func invalidManualInputDoesNotChangeCards() {
        let model = DeckViewModel()
        for cardID in ["", "06113/", "https://arkhamdb.com/card/06113"] {
            #expect(!model.addCard(cardID: cardID, quantity: "1"))
        }
        for quantity in ["", "0", "-1", "1.5", "abc", "999999999999999999999"] {
            #expect(!model.addCard(cardID: "06113", quantity: quantity))
        }
        #expect(model.cards.isEmpty)
        #expect(model.errorMessage != nil)
    }

    @Test func addingExistingCardIncreasesQuantityAndReselectsIt() {
        let model = DeckViewModel()
        model.addCard(cardID: "06113", quantity: "2")
        let originalID = model.cards[0].id
        model.cards[0].isSelected = false
        #expect(model.selectedCards.isEmpty)
        #expect(model.addCard(cardID: "06113", quantity: "3"))
        #expect(model.cards.count == 1)
        #expect(model.cards[0].id == originalID)
        #expect(model.selectedCards.first?.quantity == 5)
    }

    @Test func deckLoadSelectsAllCardsAndPrintingExcludesUncheckedRows() {
        let model = DeckViewModel()
        let data = Data(#"{"investigator_code":"01001","slots":{"06113":2},"sideSlots":{"01002":1}}"#.utf8)
        model.processDeckData(data)
        #expect(model.cards.count == 3)
        #expect(model.selectedCards.count == 3)
        let uncheckedID = model.cards[1].id
        model.cards[1].isSelected = false
        #expect(model.cards.count == 3)
        #expect(model.selectedCards.count == 2)
        #expect(!model.selectedCards.contains { $0.id == uncheckedID })
        model.processDeckData(data)
        #expect(model.selectedCards.count == 3)
    }

    @Test func quantityOverflowLeavesExistingCardUnchanged() {
        let model = DeckViewModel()
        model.addCard(cardID: "06113", quantity: String(Int.max))
        #expect(!model.addCard(cardID: "06113", quantity: "1"))
        #expect(model.cards[0].quantity == Int.max)
    }

}
