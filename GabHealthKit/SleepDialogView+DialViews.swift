//
//  SleepDialogView+DialViews.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI

extension SleepDialogView {
    @ViewBuilder
    func sleepRangeArc(size: CGFloat) -> some View {
        let startProgress = progress(for: bedtimeMinutes)
        let endProgress = progress(for: wakeUpMinutes)

        ZStack {
            // 선택 구간이 12시를 지나지 않는 일반적인 경우입니다.
            // 예: 시작 12시(0.0), 끝 3시(0.25)라면 trim(0.0...0.25) 한 번으로 그릴 수 있습니다.
            if startProgress <= endProgress {
                sleepRangeArcSegment(
                    from: startProgress,
                    to: endProgress
                )
            } else {
                // 선택 구간이 12시를 지나 이어지는 경우 trim을 두 조각으로 나누어 그립니다.
                // 예: 시작 10시 방향(0.85), 끝 2시 방향(0.15)처럼 원의 끝과 시작을 넘나드는 경우입니다.
                // trim은 from 값이 to 값보다 큰 구간을 한 번에 그릴 수 없어서
                // 0.85...1.0, 0.0...0.15 두 구간으로 나누어 같은 선택 영역처럼 보이게 합니다.
                sleepRangeArcSegment(from: startProgress, to: 1)
                sleepRangeArcSegment(from: 0, to: endProgress)
            }
        }
        // sleepRangeArc 내부의 모든 좌표 계산은 이 정사각형 프레임을 기준으로 합니다.
        .frame(width: size, height: size)
        .overlay {
            // 시작 핸들입니다.
            // 전체 아크에 gesture를 붙이지 않고 이 핸들에만 gesture를 붙여야
            // 사용자가 선택 영역 아무 곳이나 눌렀을 때 값이 바뀌는 문제를 막을 수 있습니다.
            sleepRangeHandle(
                systemName: style.bedtimeIconSystemName,
                progress: startProgress,
                size: size
            ) { location in
                updateBedtime(to: snappedMinutes(from: location, in: size))
            }

            // 끝 핸들입니다.
            // 시작 핸들과 같은 계산을 쓰지만 갱신하는 상태값만 endProgress로 다릅니다.
            sleepRangeHandle(
                systemName: style.wakeUpIconSystemName,
                progress: endProgress,
                size: size
            ) { location in
                updateWakeUp(to: snappedMinutes(from: location, in: size))
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
            .inset(by: rangeStrokeGap + (rangeStrokeWidth / 2))
            // Circle 전체 둘레 중 start~end 비율만 남깁니다.
            // start/end는 각도가 아니라 0~1 사이 progress입니다.
            .trim(from: start, to: end)
            .stroke(
                style.rangeColor,
                style: StrokeStyle(
                    lineWidth: rangeStrokeWidth,
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
                .fill(style.rangeColor.opacity(0.001))

            Image(systemName: systemName)
                .font(.system(size: handleIconSize, weight: .semibold))
                .foregroundStyle(summaryPrimaryColor)
                .frame(width: handleIconSize, height: handleIconSize)
                .allowsHitTesting(false)
        }
        // 실제 보이는 캡은 stroke의 lineCap이지만, 손가락 터치를 위해 더 큰 원을 사용합니다.
        .frame(width: handleHitSize, height: handleHitSize)
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
    func dialTickLabel(text: String, angle: Double, size: CGFloat) -> some View {
        // 같은 각도에 있는 눈금 좌표와 라벨 좌표를 각각 계산합니다.
        // 라벨 좌표는 눈금 위치에서 안쪽 방향으로 텍스트 크기만큼 밀어 계산합니다.
        let tickPoint = tickPoint(
            on: size,
            angle: angle,
            inset: tickInset,
            tickHeight: majorTickHeight
        )
        let labelPoint = labelPoint(angle: angle, text: text, tickPoint: tickPoint)

        ZStack {
            // 눈금은 해당 각도에 맞게 회전시킨 뒤 계산된 좌표에 놓습니다.
            Rectangle()
                .fill(tickColor)
                .frame(width: tickWidth, height: majorTickHeight)
                .rotationEffect(.degrees(angle))
                .position(x: tickPoint.x, y: tickPoint.y)

            // 텍스트는 항상 읽기 쉬운 방향을 유지하고,
            // 위치만 원 둘레를 따라 이동시킵니다.
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tickColor)
                .lineLimit(1)
                .fixedSize()
                .position(x: labelPoint.x, y: labelPoint.y)
        }
        // 내부 position 기준이 되는 지역 좌표계를 다이얼 크기와 동일하게 맞춥니다.
        .frame(width: size, height: size)
    }

    @ViewBuilder
    func dialMinorTick(angle: Double, size: CGFloat) -> some View {
        let tickPoint = tickPoint(
            on: size,
            angle: angle,
            inset: tickInset,
            tickHeight: minorTickHeight
        )

        Rectangle()
            .fill(tickColor.opacity(minorTickOpacity))
            .frame(width: tickWidth, height: minorTickHeight)
            .rotationEffect(.degrees(angle))
            .position(x: tickPoint.x, y: tickPoint.y)
    }
}
