// MIT License - See LICENSE.txt in project root

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DeckViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Header: Input field and buttons
            VStack(spacing: 8) {
                Text("Enter Public Deck ID")
                    .font(.headline)
                
                TextField("e.g. 4745611", text: $viewModel.deckID)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button {
                        viewModel.fetchDeck()
                    } label: {
                        Text("Fetch Deck")
                            .padding(8)
                            .background(viewModel.deckID.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.deckID.isEmpty || viewModel.isLoading)
                    .buttonStyle(.plain) // Removes default macOS button background
                    
                    #if os(macOS)
                    Button {
                        if let cardsURL = viewModel.cardImageCacheDirectory() {
                            let baseCacheURL = cardsURL.deletingLastPathComponent()
                            NSWorkspace.shared.open(baseCacheURL)
                        }
                    } label: {
                        Text("Open Cache")
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    #endif
                    
                    Button {
                        viewModel.printDeck()
                    } label: {
                        Text("Print")
                            .padding(8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(viewModel.deckData.isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 0) // Remove extra horizontal padding
                
                if viewModel.isLoading {
                    ProgressView("Loading...")
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            Text("Reminders:\n(1) Deck lists are cached by default for 24 hours\n(2) Cards with missing (\"grey blank\") images are not in ArkhamDB and should be retrieved manually from other sources and saved in the cache\n(3) Print the PDF at 59% on US letter paper for the best fit")
                .font(.footnote)
                .foregroundColor(.black)
                .padding(.horizontal)
                .multilineTextAlignment(.leading)
            
            Divider()
            
            // Main content area: a scrolling list of card rows
            List(viewModel.cards) { card in
                CardRowView(card: card, viewModel: viewModel)
            }
            .listStyle(PlainListStyle())
        }
    }
}

// A single row in the list: shows the card ID, quantity, and the card image(s)
struct CardRowView: View {
    let card: CardQuantity
    @ObservedObject var viewModel: DeckViewModel
    
    @State private var cardImage: Image? = nil
    @State private var backCardImage: Image? = nil
    
    var body: some View {
        HStack(spacing: 16) {
            // Horizontal stack for card images
            HStack(spacing: 8) {
                if let cardImage = cardImage {
                    cardImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 70)
                } else {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 70)
                }
                
                if let backCardImage = backCardImage {
                    backCardImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 70)
                }
            }
            
            VStack(alignment: .leading) {
                Text(card.cardID)
                    .font(.headline)
                Text("x\(card.quantity)")
                    .font(.subheadline)
            }
            Spacer()
        }
        .onAppear {
            viewModel.retrieveCardImages(for: card.cardID) { urls in
                guard let urls = urls else { return }
                #if os(iOS)
                if let uiImage = UIImage(contentsOfFile: urls.frontLocalURL.path) {
                    cardImage = Image(uiImage: uiImage)
                }
                if let backURL = urls.backLocalURL, let uiBackImage = UIImage(contentsOfFile: backURL.path) {
                    backCardImage = Image(uiBackImage: uiBackImage)
                }
                #else
                if let nsImage = NSImage(contentsOf: urls.frontLocalURL) {
                    cardImage = Image(nsImage: nsImage)
                }
                if let backURL = urls.backLocalURL, let nsBackImage = NSImage(contentsOf: backURL) {
                    backCardImage = Image(nsImage: nsBackImage)
                }
                #endif
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DeckViewModel())
    }
}
