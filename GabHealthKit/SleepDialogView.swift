//
//  SleepDialogView.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI

struct SleepDialogView: View {
    let times: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24]
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let _ = print("상갑 logEvent \(#function) width \(width)")
            ZStack(alignment: .center) {
                Color.orange
                
                ZStack {
                    Color.blue
                    
                    ForEach(times.indices, id: \.self) { index in
                        ZStack {
                            Path { path in
                                let hours: Path = Path(CGRect(origin: CGPoint(x: (width - 100) / 2, y: 10), size: CGSize(width: 3, height: 15)))
                                path.addPath(hours)
                            }
                            .rotationEffect(.degrees(Double(30 * index)))
                        }
                    }
                    
                }
                .frame(width: width - 100, height: width - 100)
                
                Circle()
                    .stroke(Color.black.opacity(0.6), lineWidth: 40)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 30)
            .background(.black.opacity(0.9))
        }
    }
}

struct WingShape: Shape {
    let degress: Double
    
    init(degress: Double) {
        self.degress = degress
    }
    
    nonisolated func path(in rect: CGRect) -> Path {
        drawing(in: rect)
    }
    
    func drawing(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            
            path.addLine(to: CGPoint(x: 0, y: 10))
            
            path.closeSubpath()
        }
    }
}

#Preview {
    SleepDialogView()
}
