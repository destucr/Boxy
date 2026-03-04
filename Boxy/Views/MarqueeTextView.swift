//
//  MarqueeTextView.swift
//  Boxy
//
//  Created by Destu Cikal Ramdani on 2/28/26.
//

import Foundation
import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    var delay: Double = 2
    var speed: Double = 28.0
    var gap: CGFloat = 24

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isRunning = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Copy 1: starts at offset
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .fixedSize()
                    .offset(x: offset)

                // Copy 2: always exactly one cycle ahead (to the right)
                Text(text)
                    .font(font)
                    .foregroundColor(color)
                    .fixedSize()
                    .offset(x: offset + textWidth + gap)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                Text(text)
                    .font(font)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { textGeo in
                        Color.clear
                            .onAppear {
                                textWidth = textGeo.size.width
                                containerWidth = geo.size.width
                                startIfNeeded()
                            }
                            .onChange(of: text) { _ in
                                stop()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    textWidth = textGeo.size.width
                                    containerWidth = geo.size.width
                                    startIfNeeded()
                                }
                            }
                    })
            )
        }
        .clipped()
    }

    private func startIfNeeded() {
        guard textWidth > containerWidth else {
            offset = 0
            return
        }
        isRunning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isRunning else { return }
            loop()
        }
    }

    private func loop() {
        guard isRunning else { return }
        let cycleWidth = textWidth + gap
        let duration = Double(cycleWidth) / speed

        withAnimation(.linear(duration: duration)) {
            offset = -cycleWidth
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard isRunning else { return }
            // Snap back: copy 2 is now exactly where copy 1 was — seamless
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { offset = 0 }
            loop()
        }
    }

    private func stop() {
        isRunning = false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { offset = 0 }
    }
}
