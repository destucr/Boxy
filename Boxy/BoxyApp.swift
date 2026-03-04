//
//  BoxyApp.swift
//  Boxy
//
//  Created by Destu Cikal Ramdani on 3/5/26.
//

import SwiftUI
import CoreText
import UIKit

@main
struct BoxyApp: App {
    init() {
        registerFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func registerFonts() {
        // In an Xcode project, we use Bundle.main
        let bundle = Bundle.main
        
        guard let fontURL = bundle.url(forResource: "LED Dot-Matrix", withExtension: "ttf") ??
                             bundle.url(forResource: "LED Dot-Matrix", withExtension: "ttf", subdirectory: "Fonts") ??
                             bundle.url(forResource: "LED Dot-Matrix", withExtension: "ttf", subdirectory: "Resources/Fonts") else {
            print("❌ Could not find font file: LED Dot-Matrix.ttf")
            return
        }
        
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            print("⚠️ Font registration note: \(errorDescription)")
        } else {
            print("✅ Successfully registered font: LED Dot-Matrix.ttf")
        }
    }
}
