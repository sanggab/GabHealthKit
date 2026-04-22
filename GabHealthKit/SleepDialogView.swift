//
//  SleepDialogView.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI

enum ClockHour: Int, CaseIterable {
    case midnight = 0
    case twoAM = 2
    case fourAM = 4
    case sixAM = 6
    case eightAM = 8
    case tenAM = 10
    case noon = 12
    case twoPM = 14
    case fourPM = 16
    case sixPM = 18
    case eightPM = 20
    case tenPM = 22

    var displayText: String {
        switch self {
        case .midnight: "오전12시"
        case .sixAM: "오전6시"
        case .noon: "오후12시"
        case .sixPM: "오후6시"
        case .twoAM, .twoPM: "2"
        case .fourAM, .fourPM: "4"
        case .eightAM, .eightPM: "8"
        case .tenAM, .tenPM: "10"
        }
    }
}

struct SleepDialogView: View {
    let times: [ClockHour] = ClockHour.allCases
    private let dialLabelWidth: CGFloat = 52
    
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let dialSize = width - 100

            ZStack(alignment: .center) {
                Color.orange
                
                ZStack {
                    Color.blue
                    
                    ForEach(times.indices, id: \.self) { index in
                        let time = times[index]

                        dialTickLabel(
                            text: time.displayText,
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
        let _ = print("상갑 logEvent \(#function) angle \(angle)")
        VStack(spacing: 10) {
            Rectangle()
                .fill(.white)
                .frame(width: 3, height: 15)

            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: dialLabelWidth)
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
