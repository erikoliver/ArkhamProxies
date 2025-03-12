// MIT License - See LICENSE.txt in project root

import SwiftUI
#if os(macOS)
import AppKit
import PDFKit
#endif

// Model representing a card and its quantity
struct CardQuantity: Identifiable, Hashable {
    let id: UUID = UUID()    // unique for each instance
    let cardID: String       // the actual card id from the deck JSON
    let quantity: Int
}
// Struct representing local URLs for card images
struct CardImageURLs {
    let frontLocalURL: URL
    let backLocalURL: URL?
}

// Struct for decoding card JSON from the API
struct CardData: Decodable {
    let imagesrc: String
    let backimagesrc: String?
}

// Struct for decoding the deck JSON
struct Deck: Decodable {
    let investigator_code: String
    let slots: [String: Int]
    let sideSlots: [String: Int]
    
    private enum CodingKeys: String, CodingKey {
        case investigator_code, slots, sideSlots
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        investigator_code = try container.decode(String.self, forKey: .investigator_code)
        slots = try container.decodeIfPresent([String: Int].self, forKey: .slots) ?? [:]
        if let dict = try? container.decode([String: Int].self, forKey: .sideSlots) {
            sideSlots = dict
        } else {
            // In case sideSlots is empty or not a dictionary, default to empty dictionary
            sideSlots = [:]
        }
    }
}

// ViewModel containing the logic for fetching deck data and extracting card IDs
class DeckViewModel: ObservableObject {
    @Published var deckID: String = ""
    @Published var deckData: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var cards: [CardQuantity] = []
    
    func fetchDeck() {
        guard !deckID.isEmpty else { return }
        
        // Define the cache file path for this deck.
        guard let deckCacheDir = deckCacheDirectory() else {
            errorMessage = "Deck cache directory unavailable."
            return
        }
        let deckCacheFile = deckCacheDir.appendingPathComponent("\(deckID).json")
        
        // If the cached JSON file exists, check its modification date.
        if FileManager.default.fileExists(atPath: deckCacheFile.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: deckCacheFile.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                let elapsedTime = Date().timeIntervalSince(modificationDate)
                if elapsedTime < 86400 {
                    // Cached file is less than 24 hours old; use it.
                    do {
                        let cachedData = try Data(contentsOf: deckCacheFile)
                        DispatchQueue.main.async {
                            self.processDeckData(cachedData)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to read cached deck JSON: \(error.localizedDescription)"
                        }
                    }
                    return
                } else {
                    // Cached file is older than 24 hours; delete it.
                    do {
                        try FileManager.default.removeItem(at: deckCacheFile)
                    } catch {
                        print("Failed to delete old cached deck JSON: \(error)")
                    }
                }
            }
        }
        
        // Otherwise, fetch the deck JSON from the API.
        guard let url = URL(string: "https://arkhamdb.com/api/public/deck/\(deckID).json") else {
            errorMessage = "Invalid URL."
            return
        }
        isLoading = true
        errorMessage = nil
        deckData = ""
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received."
                }
                return
            }
            // Save the fetched JSON to the cache.
            do {
                try data.write(to: deckCacheFile)
            } catch {
                print("Failed to write deck JSON to cache: \(error)")
            }
            DispatchQueue.main.async {
                self.processDeckData(data)
            }
        }.resume()
    }

    /// Helper function that decodes the deck JSON data and updates the view model.
    func processDeckData(_ data: Data) {
        do {
            let deck = try JSONDecoder().decode(Deck.self, from: data)
            var cardList = [CardQuantity]()
            // Add the investigator_code with a default quantity of 1.
            cardList.append(CardQuantity(cardID: deck.investigator_code, quantity: 1))
            // Add cards from the slots dictionary.
            for (cardID, quantity) in deck.slots {
                cardList.append(CardQuantity(cardID: cardID, quantity: quantity))
            }
            for (cardID, quantity) in deck.sideSlots {
                cardList.append(CardQuantity(cardID: cardID, quantity: quantity))
            }
            self.cards = cardList
            // Optionally store raw JSON for debugging.
            self.deckData = String(data: data, encoding: .utf8) ?? ""
        } catch {
            self.errorMessage = "Failed to decode deck JSON: \(error.localizedDescription)"
        }
    }
    
    func cardImageCacheDirectory() -> URL? {
        let fm = FileManager.default
        if let cachesDirectory = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            // Use the bundle identifier if available, else default to "com.oliver"
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let baseCacheFolder = cachesDirectory.appendingPathComponent(bundleID)
            // Ensure base cache folder exists
            if !fm.fileExists(atPath: baseCacheFolder.path) {
                do {
                    try fm.createDirectory(at: baseCacheFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create base cache directory: \(error)")
                    return nil
                }
            }
            // Create the "Cards" subfolder
            let cardsFolder = baseCacheFolder.appendingPathComponent("Cards")
            if !fm.fileExists(atPath: cardsFolder.path) {
                do {
                    try fm.createDirectory(at: cardsFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create Cards cache folder: \(error)")
                    return nil
                }
            }
            return cardsFolder
        }
        return nil
    }

    
    func deckCacheDirectory() -> URL? {
        let fm = FileManager.default
        if let cachesDirectory = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let bundleID = Bundle.main.bundleIdentifier ?? "com.oliver"
            let baseCacheFolder = cachesDirectory.appendingPathComponent(bundleID)
            // Ensure base cache folder exists
            if !fm.fileExists(atPath: baseCacheFolder.path) {
                do {
                    try fm.createDirectory(at: baseCacheFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create base cache directory: \(error)")
                    return nil
                }
            }
            // Create the "Decks" subfolder
            let decksFolder = baseCacheFolder.appendingPathComponent("Decks")
            if !fm.fileExists(atPath: decksFolder.path) {
                do {
                    try fm.createDirectory(at: decksFolder, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    print("Failed to create Decks cache folder: \(error)")
                    return nil
                }
            }
            return decksFolder
        }
        return nil
    }

    // Checks the cache for a card's front and back image files
    func cachedCardImageURLs(for cardID: String) -> CardImageURLs? {
        guard let cacheDir = cardImageCacheDirectory() else { return nil }
        let fm = FileManager.default
        var frontURL: URL?
        var backURL: URL?
        let extensions = [".png", ".jpg"]
        
        for ext in extensions {
            let potentialFront = cacheDir.appendingPathComponent(cardID + ext)
            if fm.fileExists(atPath: potentialFront.path) {
                frontURL = potentialFront
                break
            }
        }
        
        for ext in extensions {
            let potentialBack = cacheDir.appendingPathComponent(cardID + "b" + ext)
            if fm.fileExists(atPath: potentialBack.path) {
                backURL = potentialBack
                break
            }
        }
        
        if let frontURL = frontURL {
            return CardImageURLs(frontLocalURL: frontURL, backLocalURL: backURL)
        }
        return nil
    }
    
    // Retrieves card images by first checking the cache; if not found, fetches card data from the API, downloads the images, and caches them
    func retrieveCardImages(for cardID: String, completion: @escaping (CardImageURLs?) -> Void) {
        // Check cache first
        if let cached = cachedCardImageURLs(for: cardID) {
            completion(cached)
            return
        }
        
        // Not in cache; fetch card data from API
        guard let apiURL = URL(string: "https://arkhamdb.com/api/public/card/\(cardID).json") else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: apiURL) { data, response, error in
            if let error = error {
                print("Error fetching card data: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            do {
                let cardData = try JSONDecoder().decode(CardData.self, from: data)
                let baseURL = "https://arkhamdb.com"
                guard let frontImageURL = URL(string: baseURL + cardData.imagesrc) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                // Determine file extension for front image
                var frontExt = frontImageURL.pathExtension
                if frontExt.isEmpty { frontExt = "png" }
                
                guard let cacheDir = self.cardImageCacheDirectory() else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                let frontLocalURL = cacheDir.appendingPathComponent("\(cardID).\(frontExt)")
                
                let downloadGroup = DispatchGroup()
                
                downloadGroup.enter()
                URLSession.shared.dataTask(with: frontImageURL) { imageData, response, error in
                    if let imageData = imageData {
                        do {
                            try imageData.write(to: frontLocalURL)
                        } catch {
                            print("Error writing front image: \(error)")
                        }
                    } else {
                        print("No front image data for card \(cardID)")
                    }
                    downloadGroup.leave()
                }.resume()
                
                var backLocalURL: URL? = nil
                if let backSrc = cardData.backimagesrc, !backSrc.isEmpty, let backImageURL = URL(string: baseURL + backSrc) {
                    var backExt = backImageURL.pathExtension
                    if backExt.isEmpty { backExt = "png" }
                    backLocalURL = cacheDir.appendingPathComponent("\(cardID)b.\(backExt)")
                    
                    downloadGroup.enter()
                    URLSession.shared.dataTask(with: backImageURL) { imageData, response, error in
                        if let imageData = imageData {
                            do {
                                try imageData.write(to: backLocalURL!)
                            } catch {
                                print("Error writing back image: \(error)")
                            }
                        } else {
                            print("No back image data for card \(cardID)")
                        }
                        downloadGroup.leave()
                    }.resume()
                }
                
                downloadGroup.notify(queue: DispatchQueue.main) {
                    let cached = self.cachedCardImageURLs(for: cardID)
                    completion(cached)
                }
                
            } catch {
                print("Error decoding card JSON: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }
}

@main
struct Arkham_ProxiesApp: App {
    @StateObject private var viewModel = DeckViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}

extension DeckViewModel {
    func printDeck() {
        #if os(macOS)
        // Build an array of NSImage objects from the file cache.
        var imagesToPrint: [NSImage] = []
        for card in self.cards {
            if let urls = self.cachedCardImageURLs(for: card.cardID) {
                let isDoubleSided = (urls.backLocalURL != nil)
                for _ in 0..<card.quantity {
                    if let frontImage = NSImage(contentsOf: urls.frontLocalURL) {
                        imagesToPrint.append(frontImage)
                    }
                    if isDoubleSided, let backURL = urls.backLocalURL, let backImage = NSImage(contentsOf: backURL) {
                        imagesToPrint.append(backImage)
                    }
                }
            }
        }
        
        print("Total images to print: \(imagesToPrint.count)")
        
        // Layout: 3x3 grid per page.
        let tilesPerPage = 9
        let tileWidth: CGFloat = 300
        let tileHeight: CGFloat = 419
        let pageWidth = tileWidth * 3
        let pageHeight = tileHeight * 3
        
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        // Create PDF context writing to a temporary file.
        let tempDirectory = FileManager.default.temporaryDirectory
        let pdfURL = tempDirectory.appendingPathComponent("DeckPrint.pdf")
        guard let pdfContext = CGContext(pdfURL as CFURL, mediaBox: &mediaBox, nil) else {
            print("Failed to create PDF context")
            return
        }
        
        var index = 0
        var pageNumber = 1
        while index < imagesToPrint.count {
            pdfContext.beginPage(mediaBox: &mediaBox)
            pdfContext.setFillColor(NSColor.white.cgColor)
            pdfContext.fill(mediaBox)
                        
            for row in 0..<3 {
                for col in 0..<3 {
                    let tileIndex = index + row * 3 + col
                    if tileIndex < imagesToPrint.count {
                        // Before drawing, apply the orientedImageIfNeeded.
                        let image = orientedImageIfNeeded(imagesToPrint[tileIndex])
                        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                            let destRect = CGRect(x: CGFloat(col) * tileWidth,
                                                  y: pageHeight - CGFloat(row + 1) * tileHeight,
                                                  width: tileWidth,
                                                  height: tileHeight)
                            pdfContext.draw(cgImage, in: destRect)
                        }
                    }
                }
            }
            
            pdfContext.endPage()
            index += tilesPerPage
            pageNumber += 1
        }
        pdfContext.closePDF()
        
        // Create a PDFDocument from the generated PDF data.
        // Create a PDFDocument from the generated PDF data.
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            print("Failed to create PDFDocument")
            return
        }

        // Configure print info.
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: pageWidth, height: pageHeight)
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0

        // Create a view wrapping the PDF for printing using our new PDFPrinterView.
        let printViewFrame = NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let printView = PDFPrinterView(document: pdfDoc, frame: printViewFrame)
        let printOperation = NSPrintOperation(view: printView)
        printOperation.run()
        
        #else
        print("Printing is only available on macOS.")
        #endif
    }
    
    #if os(macOS)
    func orientedImageIfNeeded(_ image: NSImage) -> NSImage {
        let size = image.size
        if size.width > size.height {
            // Rotate image by -90 degrees (clockwise rotation)
            let rotatedImage = NSImage(size: NSSize(width: size.height, height: size.width))
            rotatedImage.lockFocus()
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: size.width)
            transform.rotate(byDegrees: -90)
            transform.concat()
            image.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height),
                       from: NSRect(origin: .zero, size: size),
                       operation: .copy,
                       fraction: 1.0)
            rotatedImage.unlockFocus()
            return rotatedImage
        }
        return image
    }
    #endif
}

#if os(macOS)
import PDFKit

// Replace the existing PDFPrintView with this custom view for printing.
class PDFPrinterView: NSView {
    var pdfDocument: PDFDocument
    
    init(document: PDFDocument, frame: NSRect) {
        self.pdfDocument = document
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Override printing methods.
    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let count = pdfDocument.pageCount
        range.pointee = NSMakeRange(1, count)
        return true
    }
    
    override func rectForPage(_ page: Int) -> NSRect {
        if let pdfPage = pdfDocument.page(at: page - 1) {
            // Use the PDF page's mediaBox
            return pdfPage.bounds(for: .mediaBox)
        }
        return self.bounds
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        // Get the current page number from the printing operation.
        // NSPrintOperation.current may be nil if not printing, so default to page 1.
        let currentPage = NSPrintOperation.current?.currentPage ?? 1
        if let pdfPage = pdfDocument.page(at: currentPage - 1) {
            // Draw the PDF page into the current context.
            pdfPage.draw(with: .mediaBox, to: context)
        }
    }
}
#endif
