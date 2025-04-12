# Arkham Horror: The Card Game -- Proxy Deck Tool (macOS)

## Context (Why)

Ever bring Arkham Horror: The Card Game out to play and wish you could add a previewed card to your deck? **I did.**  

*Enter the proxy deck tool*. 

This tool is designed to help you take an [ArkhamDB](http://arkhamdb.com) deck and easily print the handful of preview cards you need.

## Reminder about Copyright and IP

This tool is for players who have purchased Arkham Horror: The Card Game from Fantasy Flight Games (FFG) and want an easier way to incorporate previewed cards into their decks. It should not be used for unauthorized duplication of FFG's IP.

## How to use the tool

### Step 1 - Build your deck on ArkhamDB

Build a deck in [ArkhamDB](http://arkhamdb.com).

Make sure your account settings have "Make your decks public" checked. 

Take note of the deck #, e.g. for [https://arkhamdb.com/deck/view/4745611](https://arkhamdb.com/deck/view/4745611) the relevant part would be the "4745611". 

### Step 2 - Launch the Arkham Proxies app

The app will have a space for you to enter the deckID, e.g. "4745611". Once you do that click the "Fetch Deck" button and allow the program to download the ArkhamDB card images.

**NOTE 1: Missing Images**: If the image is not in ArkhamDB it will stay a grey box in the tool. You can use the "Open Cache" button and store a file in the "Cards" subfolder based on the card #. For example ["The Book of War"](https://arkhamdb.com/card/11020) is "11020" so if you go to a preview image with Book of War and save the file as "11020.jpg" or "11020.png" inside the "Cards" subfolder and re-fetch the deck, it will get the image.

**NOTE 2: Caching**: To reduce any impacts on ArkhamDB, by default decks and images are cached. Images "forever" and decks will only be refreshed if 24 hours have passed. Clear the appropriate cached item in "Cards" or "Decks" if you need the data reloaded

### Step 3 - Printing

When you are happy with what is shown click print and you can either directly print or save a PDF.

**Recommended Settings**: Print on US Letter paper with scaling set to 59%.

## Download

Source is here on Github.

Notarized Mac Binary is under [releases](https://github.com/erikoliver/ArkhamProxies/releases)
