//
//  SleepDialogView.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI

enum Clock {
    enum Hours {
        case afternoon
    }
}

struct SleepDialogView: View {
    let times: [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22]
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dialSize = width - 100

            ZStack(alignment: .center) {
                Color.orange
                
                ZStack {
                    Color.blue
                    
                    ForEach(times.indices, id: \.self) { index in
                        dialTickLabel(
                            text: "\(times[index])",
                            angle: Double(30 * index),
                            size: dialSize
                        )
                    }
                    
                }
                .frame(width: dialSize, height: dialSize)
                
                Circle()
                    .stroke(Color.black.opacity(0.6), lineWidth: 40)
                
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 30)
            .background(.black.opacity(0.9))
        }
    }

    @ViewBuilder
    private func dialTickLabel(text: String, angle: Double, size: CGFloat) -> some View {
        VStack(spacing: 10) {
            
            Rectangle()
                .fill(.white)
                .frame(width: 3, height: 15)
            
            
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-angle))

            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .frame(width: size, height: size)
        .rotationEffect(.degrees(angle))
    }
}

#Preview {
    SleepDialogView()
}
