import SwiftUI

struct CreditsView: View {
    var body: some View {
        ZStack {
            Color(red: 0xF7/255, green: 0xF7/255, blue: 0xF6/255).ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Text("CREDITS")
                        .font(.custom("LED Dot-Matrix", size: 24))
                        .foregroundColor(.black)
                }
                .padding(.top, 40)
                
                Divider()
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 24) {
                    CreditItem(
                        title: "VISUAL DESIGN & INTERFACE",
                        description: "Design by",
                        author: "Sardor Abdujalolov",
                        link: "https://dribbble.com/shots/23964921-Skeumorphic-media-player"
                    )
                    
                    CreditItem(
                        title: "AUDIO ARCHIVE & RECORDINGS",
                        description: "Classical music recordings and audio resources from the classicals archive.",
                        author: "Classicals.de",
                        link: "https://www.classicals.de/"
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
            }
        }
    }
}

struct CreditItem: View {
    let title: String
    let description: String
    let author: String
    let link: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("LED Dot-Matrix", size: 10))
                .foregroundColor(.black.opacity(0.6))
            
            Text(description)
                .font(.custom("LED Dot-Matrix", size: 12))
                .foregroundColor(.black.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Link(destination: URL(string: link)!) {
                HStack(spacing: 4) {
                    Text(author)
                        .font(.custom("LED Dot-Matrix", size: 14))
                        .foregroundColor(.black)
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8))
                        .foregroundColor(.black.opacity(0.7))
                }
                .padding(.vertical, 4)
            }
        }
    }
}
