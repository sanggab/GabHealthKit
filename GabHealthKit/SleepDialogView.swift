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
    // 선택된 수면 구간의 시작/끝 위치입니다.
    // 0.0은 12시 방향, 0.25는 3시 방향, 0.5는 6시 방향을 의미합니다.
    // SwiftUI trim(from:to:)이 0~1 사이 값을 사용하기 때문에
    // 시간을 각도 대신 progress 값으로 보관합니다.
    @State private var sleepRangeStartProgress = 0.0
    @State private var sleepRangeEndProgress = 0.25

    // 다이얼을 따라 배치할 시간 목록입니다.
    let times: [ClockHour] = ClockHour.allCases

    // 2시간 단위의 시간 눈금 사이를 15분 단위로 나눈 전체 칸 수입니다.
    // 시간 눈금 12개 * 각 시간 눈금 사이 4칸 = 48칸입니다.
    private let totalTickSlots = 48

    // 4칸마다 시간 눈금이 오고, 그 사이 3칸은 분금으로 사용합니다.
    private let majorTickSlotInterval = 4

    // 좌우 여백입니다. 다이얼 지름은 이 값을 제외한 실제 가용 폭 기준으로 계산합니다.
    private let horizontalPadding: CGFloat = 30

    // 다이얼 테두리 두께입니다. -> 시계 눈금의 위치에 영향을 미칩니다.
    private let dialStrokeWidth: CGFloat = 40

    // 드래그로 늘어나는 선택 링의 두께입니다.
    private let sleepRangeStrokeWidth: CGFloat = 30

    // 선택 링이 검은 테두리 안에서 위아래로 남길 여백입니다.
    private let sleepRangeStrokeGap: CGFloat = 5

    // 시작/끝 핸들의 터치 영역입니다.
    // 실제로 보이는 원형 캡보다 크게 잡아 손가락으로 잡기 쉽게 합니다.
    // 이 값이 작으면 사용자가 정확히 캡을 눌러야 해서 드래그가 불편해집니다.
    private let sleepRangeHandleHitSize: CGFloat = 44

    // 시작/끝 핸들에 표시할 SF Symbols 아이콘 크기입니다.
    private let sleepRangeHandleIconSize: CGFloat = 20

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

                    ForEach(0..<totalTickSlots, id: \.self) { index in
                        // 시간 눈금이 그려지는 자리는 분금을 중복으로 그리지 않습니다.
                        if index % majorTickSlotInterval != 0 {
                            dialMinorTick(
                                angle: Double(index) * (360 / Double(totalTickSlots)),
                                size: dialSize
                            )
                        }
                    }
                    
                    ForEach(times.indices, id: \.self) { index in
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

                sleepRangeArc(size: dialSize)
                
                AsyncImage(url: URL(string: "https://blog.treasurer.co.kr/assets/img/treasurer/rolex/rolex_12.png")) { result in
                    result.image?
                        .resizable()
                }
                .frame(width: 100, height: 100)
                
            }
            // GeometryReader가 제공한 전체 영역을 모두 사용합니다.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.orange)
            .padding(.horizontal, horizontalPadding)
            .background(.black.opacity(0.9))
        }
    }

    @ViewBuilder
    private func sleepRangeArc(size: CGFloat) -> some View {
        ZStack {
            // 선택 구간이 12시를 지나지 않는 일반적인 경우입니다.
            // 예: 시작 12시(0.0), 끝 3시(0.25)라면 trim(0.0...0.25) 한 번으로 그릴 수 있습니다.
            if sleepRangeStartProgress <= sleepRangeEndProgress {
                sleepRangeArcSegment(
                    from: sleepRangeStartProgress,
                    to: sleepRangeEndProgress
                )
            } else {
                // 선택 구간이 12시를 지나 이어지는 경우 trim을 두 조각으로 나누어 그립니다.
                // 예: 시작 10시 방향(0.85), 끝 2시 방향(0.15)처럼 원의 끝과 시작을 넘나드는 경우입니다.
                // trim은 from 값이 to 값보다 큰 구간을 한 번에 그릴 수 없어서
                // 0.85...1.0, 0.0...0.15 두 구간으로 나누어 같은 선택 영역처럼 보이게 합니다.
                sleepRangeArcSegment(from: sleepRangeStartProgress, to: 1)
                sleepRangeArcSegment(from: 0, to: sleepRangeEndProgress)
            }
        }
        // sleepRangeArc 내부의 모든 좌표 계산은 이 정사각형 프레임을 기준으로 합니다.
        .frame(width: size, height: size)
        .overlay {
            // 시작 핸들입니다.
            // 전체 아크에 gesture를 붙이지 않고 이 핸들에만 gesture를 붙여야
            // 사용자가 선택 영역 아무 곳이나 눌렀을 때 값이 바뀌는 문제를 막을 수 있습니다.
            sleepRangeHandle(
                systemName: "moon.stars.fill",
                progress: sleepRangeStartProgress,
                size: size
            ) { location in
                sleepRangeStartProgress = progress(from: location, in: size)
            }

            // 끝 핸들입니다.
            // 시작 핸들과 같은 계산을 쓰지만 갱신하는 상태값만 endProgress로 다릅니다.
            sleepRangeHandle(
                systemName: "alarm.fill",
                progress: sleepRangeEndProgress,
                size: size
            ) { location in
                sleepRangeEndProgress = progress(from: location, in: size)
            }
        }
        // DragGesture의 location을 이 다이얼 프레임 기준 좌표로 받기 위한 이름 있는 좌표계입니다.
        // 이 좌표계가 없으면 부모 뷰 기준 좌표가 들어와 원 중심 계산이 어긋날 수 있습니다.
        .coordinateSpace(name: "sleepRangeDial")
    }

    private func sleepRangeArcSegment(from start: Double, to end: Double) -> some View {
        Circle()
            // trim을 쓰려면 strokeBorder 대신 stroke를 사용해야 합니다.
            // stroke는 선이 path 중심을 기준으로 그려지므로, 원하는 여백 + 선 반두께만큼 inset합니다.
            // 예: gap 5, lineWidth 30이면 path 중심은 바깥쪽에서 20pt 안쪽에 있어야
            // 실제 선의 바깥쪽 edge가 테두리보다 5pt 안쪽에 그려집니다.
            .inset(by: sleepRangeStrokeGap + (sleepRangeStrokeWidth / 2))
            // Circle 전체 둘레 중 start~end 비율만 남깁니다.
            // start/end는 각도가 아니라 0~1 사이 progress입니다.
            .trim(from: start, to: end)
            .stroke(
                Color.mint,
                style: StrokeStyle(
                    lineWidth: sleepRangeStrokeWidth,
                    // 라운드 캡을 써야 iOS 수면 시간 선택 UI처럼 양 끝이 둥글게 보입니다.
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            // SwiftUI Circle trim의 시작점은 3시 방향이라, 시계처럼 12시부터 시작하도록 돌립니다.
            .rotationEffect(.degrees(-90))
    }

    private func sleepRangeHandle(
        systemName: String,
        progress: Double,
        size: CGFloat,
        onDrag: @escaping (CGPoint) -> Void
    ) -> some View {
        // 현재 progress 값이 실제 원 위 어느 좌표인지 계산합니다.
        // 이 좌표에 투명한 터치 영역을 올려 사용자가 시작/끝만 드래그하게 만듭니다.
        let point = sleepRangePoint(progress: progress, size: size)

        return ZStack {
            Circle()
                // 투명에 가까운 색을 넣어 실제 UI는 해치지 않으면서 터치 영역만 확보합니다.
                // Color.clear만 쓰면 상황에 따라 hit testing이 기대처럼 동작하지 않을 수 있어
                // 거의 보이지 않는 opacity를 가진 색으로 터치 가능한 Shape를 만듭니다.
                .fill(Color.mint.opacity(0.001))

            Image(systemName: systemName)
                .frame(width: size, height: size)
                .allowsHitTesting(false)
        }
        // 실제 보이는 캡은 stroke의 lineCap이지만, 손가락 터치를 위해 더 큰 원을 사용합니다.
        .frame(width: sleepRangeHandleHitSize, height: sleepRangeHandleHitSize)
            // 프레임 전체 사각형이 아니라 원형 영역만 터치 영역으로 사용합니다.
            .contentShape(Circle())
            // 계산된 캡 좌표에 투명 핸들을 올립니다.
            .position(x: point.x, y: point.y)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("sleepRangeDial"))
                    .onChanged { value in
                        // value.location은 sleepRangeDial 좌표계 기준입니다.
                        // 부모 화면 좌표가 아니라 다이얼 내부 좌표라서 progress 계산에 바로 사용할 수 있습니다.
                        onDrag(value.location)
                    }
            )
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
        let radians = Double(Angle.degrees(angle - 90).radians)
        let center = size / 2

        // 원의 중심점에서 cos/sin을 이용해 현재 각도의 x, y 좌표를 계산합니다.
        return CGPoint(
            x: center + (CGFloat(Darwin.cos(radians)) * radius),
            y: center + (CGFloat(Darwin.sin(radians)) * radius)
        )
    }

    private func labelPoint(angle: Double, text: String, tickPoint: CGPoint) -> CGPoint {
        let radians = Double(Angle.degrees(angle - 90).radians)
        let outwardVector = CGVector(
            dx: CGFloat(Darwin.cos(radians)),
            dy: CGFloat(Darwin.sin(radians))
        )
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

    private func progress(from location: CGPoint, in size: CGFloat) -> Double {
        // 드래그 좌표를 원 중심 기준 벡터로 바꿉니다.
        // 예: 사용자가 오른쪽을 누르면 dx는 양수, dy는 0에 가깝습니다.
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y

        // atan2 기준 각도는 3시 방향이 0도라서, 시계 기준 12시가 0이 되도록 90도를 더합니다.
        // SwiftUI 좌표계는 y가 아래로 증가하므로 atan2(dy, dx)를 그대로 사용하면
        // 시계 방향으로 progress가 증가하는 형태가 됩니다.
        var degrees = atan2(dy, dx) * 180 / .pi + 90

        // atan2 결과는 음수 각도가 나올 수 있으므로 0~360도 범위로 보정합니다.
        if degrees < 0 {
            degrees += 360
        }

        // trim과 같은 0~1 사이 progress 값으로 변환합니다.
        return min(max(degrees / 360, 0), 1)
    }

    private func sleepRangePoint(progress: Double, size: CGFloat) -> CGPoint {
        // sleepRangeArcSegment와 같은 원 path 위에 핸들을 올려야
        // 실제 보이는 라운드 캡 위치와 드래그 가능한 위치가 일치합니다.
        // sleepRangeArcSegment에서 사용한 inset 계산을 여기서도 동일하게 사용합니다.
        let inset = sleepRangeStrokeGap + (sleepRangeStrokeWidth / 2)
        let radius = (size / 2) - inset

        // progress는 0~1 값이므로 360도를 곱해 각도로 바꿉니다.
        // -90도 보정은 0 progress가 3시가 아니라 12시 방향에 오게 하기 위함입니다.
        let radians = (progress * 360 - 90) * Double.pi / 180
        let center = size / 2

        // 원 중심에서 해당 각도의 반지름만큼 이동한 실제 핸들 좌표입니다.
        return CGPoint(
            x: center + (CGFloat(Darwin.cos(radians)) * radius),
            y: center + (CGFloat(Darwin.sin(radians)) * radius)
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
