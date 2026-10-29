import Foundation

// ApolloWallpaperSetInfo - contains info about a wallpaper set
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ApolloWallpaperSetInfo {
    
    let name: String
    let wallpapers: [String]
    let price: Double
    
    init(name: String, wallpapers: [String], price: Double) {
        self.name = name
        self.wallpapers = wallpapers
        self.price = price
    }
}
