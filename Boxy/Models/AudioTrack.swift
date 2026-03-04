import Foundation

public struct AudioTrack: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let filename: String
    public let artist: String?
    
    public init(title: String, filename: String, artist: String? = nil) {
        self.title = title
        self.filename = filename
        self.artist = artist
    }
}

public enum RadioFilter: String, CaseIterable {
    case amRadio = "AM Radio"
    case fmVintage = "FM Vintage"
    case hamRadio = "Ham Radio"
}
