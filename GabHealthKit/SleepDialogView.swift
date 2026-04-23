//
//  SleepDialogView.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI
import UIKit

// 시계 다이얼에 표시할 시간을 2시간 단위로 관리합니다.
// rawValue는 실제 시(hour) 값이고, CaseIterable을 통해 화면에 순서대로 배치합니다.
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

    // 화면에 그대로 노출할 텍스트입니다.
    // 12시, 6시는 의미를 명확히 하기 위해 오전/오후를 모두 표기하고,
    // 나머지 시각은 다이얼을 단순하게 유지하기 위해 숫자만 사용합니다.
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
    // 다이얼을 따라 배치할 시간 목록입니다.
    let times: [ClockHour] = ClockHour.allCases

    // 각 시간 눈금 사이를 4등분해 중간에 3개의 분금을 배치합니다.
    private let minorTickOffsets = [0.25, 0.5, 0.75]

    // 좌우 여백입니다. 다이얼 지름은 이 값을 제외한 실제 가용 폭 기준으로 계산합니다.
    private let horizontalPadding: CGFloat = 30

    // 다이얼 테두리 두께입니다. -> 시계 눈금의 위치에 영향을 미칩니다.
    private let dialStrokeWidth: CGFloat = 40

    // 눈금 선의 두께입니다.
    private let dialTickWidth: CGFloat = 3

    // 눈금 선의 길이입니다.
    private let dialTickHeight: CGFloat = 15

    // 분금은 시간 눈금보다 짧게 그려 시각적 위계를 만듭니다.
    private let dialMinorTickHeight: CGFloat = 8

    // 다이얼 바깥 경계에서 눈금이 얼마나 안쪽에 들어올지 결정합니다.
    private let dialTickInset: CGFloat = 5

    // 눈금과 라벨 사이의 최소 간격입니다.
    private let dialSideLabelGap: CGFloat = 10
    
    var body: some View {
        GeometryReader { proxy in
            // padding을 제외하고 실제로 사용할 수 있는 영역 안에서
            // 가장 큰 정사각형을 다이얼 크기로 사용합니다.
            let availableWidth = max(0, proxy.size.width - (horizontalPadding * 2))
            let dialSize = min(availableWidth, proxy.size.height)

            ZStack(alignment: .center) {
                ZStack {
                    // 원형 다이얼 배경입니다.
                    Circle()
                        .fill(.blue)
                    
                    ForEach(times.indices, id: \.self) { index in
                        // 인접한 시간 눈금 사이에 3개의 분금을 먼저 배치합니다.
                        ForEach(minorTickOffsets, id: \.self) { offset in
                            dialMinorTick(
                                angle: Double(index) * 30 + (30 * offset),
                                size: dialSize
                            )
                        }

                        // 12개 시간 데이터를 30도 간격으로 시계 둘레에 배치합니다.
                        let time = times[index]

                        dialTickLabel(
                            text: time.displayText,
                            angle: Double(30 * index),
                            size: dialSize
                        )
                    }
                    
                }
                // 눈금, 라벨, 원 테두리가 모두 같은 지름을 기준으로 움직이게 합니다.
                .frame(width: dialSize, height: dialSize)
                
                // 원 테두리 역시 같은 지름 기준으로 그려 padding 변화와 분리되지 않게 합니다.
                Circle()
                    .strokeBorder(Color.black.opacity(1), lineWidth: dialStrokeWidth)
                    .frame(width: dialSize, height: dialSize)
                
//                Circle()
//                    .stroke(Color.mint, lineWidth: 30)
                
            }
            // GeometryReader가 제공한 전체 영역을 모두 사용합니다.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.orange)
            .padding(.horizontal, horizontalPadding)
            .background(.black.opacity(0.9))
        }
    }

    @ViewBuilder
    private func dialTickLabel(text: String, angle: Double, size: CGFloat) -> some View {
        // 같은 각도에 있는 눈금 좌표와 라벨 좌표를 각각 계산합니다.
        // 라벨 좌표는 눈금 위치에서 안쪽 방향으로 텍스트 크기만큼 밀어 계산합니다.
        let tickPoint = tickPoint(
            on: size,
            angle: angle,
            inset: dialTickInset,
            tickHeight: dialTickHeight
        )
        let labelPoint = labelPoint(angle: angle, text: text, tickPoint: tickPoint)

        ZStack {
            // 눈금은 해당 각도에 맞게 회전시킨 뒤 계산된 좌표에 놓습니다.
            Rectangle()
                .fill(.white)
                .frame(width: dialTickWidth, height: dialTickHeight)
                .rotationEffect(.degrees(angle))
                .position(x: tickPoint.x, y: tickPoint.y)

            // 텍스트는 항상 읽기 쉬운 방향을 유지하고,
            // 위치만 원 둘레를 따라 이동시킵니다.
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .position(x: labelPoint.x, y: labelPoint.y)
        }
        // 내부 position 기준이 되는 지역 좌표계를 다이얼 크기와 동일하게 맞춥니다.
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private func dialMinorTick(angle: Double, size: CGFloat) -> some View {
        let tickPoint = tickPoint(
            on: size,
            angle: angle,
            inset: dialTickInset,
            tickHeight: dialMinorTickHeight
        )

        Rectangle()
            .fill(.white.opacity(0.9))
            .frame(width: dialTickWidth, height: dialMinorTickHeight)
            .rotationEffect(.degrees(angle))
            .position(x: tickPoint.x, y: tickPoint.y)
    }

    private func tickPoint(on size: CGFloat, angle: Double, inset: CGFloat, tickHeight: CGFloat) -> CGPoint {
        // Swift 삼각함수 기준 0도는 3시 방향이므로,
        // 시계 기준 12시를 시작점으로 사용하려면 -90도 보정이 필요합니다.
        // tick은 원 테두리 안쪽에서부터 inset만큼 떨어진 위치에 오도록 계산합니다.
        let radius = (size / 2) - dialStrokeWidth - inset - (tickHeight / 2)
        let radians = Angle.degrees(angle - 90).radians
        let center = size / 2

        // 원의 중심점에서 cos/sin을 이용해 현재 각도의 x, y 좌표를 계산합니다.
        return CGPoint(
            x: center + cos(radians) * radius,
            y: center + sin(radians) * radius
        )
    }

    private func labelPoint(angle: Double, text: String, tickPoint: CGPoint) -> CGPoint {
        let radians = Angle.degrees(angle - 90).radians
        let outwardVector = CGVector(dx: cos(radians), dy: sin(radians))
        let labelSize = measuredLabelSize(for: text)

        // 텍스트는 회전하지 않으므로, 현재 각도에서 라벨의 가로/세로 절반 크기가
        // 반지름 방향으로 얼마나 차지하는지 투영값으로 계산합니다.
        let radialHalfExtent =
            (abs(outwardVector.dx) * labelSize.width / 2) +
            (abs(outwardVector.dy) * labelSize.height / 2)

        // 눈금 중심에서 눈금 반길이 + 최소 간격 + 라벨 반지름 방향 절반 크기만큼
        // 원의 중심 쪽으로 이동하면 각도와 관계없이 항상 일정 간격을 유지할 수 있습니다.
        let offset = (dialTickHeight / 2) + dialSideLabelGap + radialHalfExtent

        return CGPoint(
            x: tickPoint.x - (outwardVector.dx * offset),
            y: tickPoint.y - (outwardVector.dy * offset)
        )
    }

    private func measuredLabelSize(for text: String) -> CGSize {
        // iOS 17 기준 caption + semibold 조합과 같은 UIFont로 텍스트 크기를 계산해
        // SwiftUI Text가 실제로 차지할 영역에 맞춰 위치를 보정합니다.
        let baseFont = UIFont.preferredFont(forTextStyle: .caption1)
        let font = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)

        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}

#Preview {
    // SwiftUI Preview에서 다이얼 배치를 바로 확인할 수 있는 진입점입니다.
    SleepDialogView()
}
