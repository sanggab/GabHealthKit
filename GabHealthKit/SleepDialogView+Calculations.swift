//
//  SleepDialogView+Calculations.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI
import UIKit

extension SleepDialogView {
    func tickPoint(on size: CGFloat, angle: Double, inset: CGFloat, tickHeight: CGFloat) -> CGPoint {
        // Swift 삼각함수 기준 0도는 3시 방향이므로,
        // 시계 기준 12시를 시작점으로 사용하려면 -90도 보정이 필요합니다.
        // tick은 원 테두리 안쪽에서부터 inset만큼 떨어진 위치에 오도록 계산합니다.
        let radius = (size / 2) - style.borderWidth - inset - (tickHeight / 2)
        let radians = Double(Angle.degrees(angle - 90).radians)
        let center = size / 2

        // 원의 중심점에서 cos/sin을 이용해 현재 각도의 x, y 좌표를 계산합니다.
        return CGPoint(
            x: center + (CGFloat(Darwin.cos(radians)) * radius),
            y: center + (CGFloat(Darwin.sin(radians)) * radius)
        )
    }

    func labelPoint(angle: Double, text: String, tickPoint: CGPoint) -> CGPoint {
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
        let offset = (majorTickHeight / 2) + tickLabelGap + radialHalfExtent

        return CGPoint(
            x: tickPoint.x - (outwardVector.dx * offset),
            y: tickPoint.y - (outwardVector.dy * offset)
        )
    }

    func progress(from location: CGPoint, in size: CGFloat) -> Double {
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

    func progress(for minutes: Int) -> Double {
        // 24시간을 한 바퀴로 쓰기 때문에 현재 분을 하루 전체 분 수로 나누면
        // trim과 핸들 좌표 계산에 바로 사용할 수 있는 0~1 progress가 됩니다.
        Double(minutes) / Double(effectiveMinutesPerDay)
    }

    func snappedMinutes(from location: CGPoint, in size: CGFloat) -> Int {
        // 드래그 좌표를 먼저 0~1 progress로 바꾸고, 다시 하루 기준 분으로 변환합니다.
        let rawMinutes = Int((progress(from: location, in: size) * Double(effectiveMinutesPerDay)).rounded())

        // 사용자가 드래그하는 동안 시간이 너무 촘촘하게 변하지 않도록
        // 가장 가까운 5분 단위로 반올림합니다.
        let snappedMinutes = ((rawMinutes + (effectiveMinuteSnapInterval / 2)) / effectiveMinuteSnapInterval) * effectiveMinuteSnapInterval

        // 24:00 위치까지 올라간 값은 다시 0:00으로 순환시켜 24시간 다이얼을 유지합니다.
        return snappedMinutes % effectiveMinutesPerDay
    }

    func updateBedtime(to proposedBedtimeMinutes: Int) {
        // moon 핸들을 움직였을 때, 기존 기상 시간과의 차이를 계산합니다.
        // 차이가 policy의 최소~최대 수면 시간 범위 안이면 취침 시간만 독립적으로 이동합니다.
        let proposedDuration = sleepDuration(
            from: proposedBedtimeMinutes,
            to: wakeUpMinutes
        )

        if proposedDuration < effectiveMinimumSleepDurationMinutes {
            // 최소 수면 시간보다 좁혀지는 순간부터는 두 핸들이 한 몸처럼 움직입니다.
            // 사용자가 잡고 있는 moon 핸들은 그대로 따라가고,
            // alarm 핸들은 최소 수면 시간만큼 뒤로 같이 밀립니다.
            bedtimeMinutes = proposedBedtimeMinutes
            wakeUpMinutes = normalizedMinutes(proposedBedtimeMinutes + effectiveMinimumSleepDurationMinutes)
        } else if proposedDuration > effectiveMaximumSleepDurationMinutes {
            // 최대 수면 시간보다 길어지는 순간부터도 두 핸들이 한 몸처럼 움직입니다.
            // 사용자가 잡고 있는 moon 핸들은 그대로 따라가고,
            // alarm 핸들은 최대 수면 시간만큼 뒤 위치로 같이 이동합니다.
            bedtimeMinutes = proposedBedtimeMinutes
            wakeUpMinutes = normalizedMinutes(proposedBedtimeMinutes + effectiveMaximumSleepDurationMinutes)
        } else {
            // 최소~최대 수면 시간 범위 안에서는 다시 각자의 핸들처럼 독립 이동합니다.
            bedtimeMinutes = proposedBedtimeMinutes
        }
    }

    func updateWakeUp(to proposedWakeUpMinutes: Int) {
        // alarm 핸들을 움직였을 때, 기존 취침 시간과의 차이를 계산합니다.
        // 차이가 policy의 최소~최대 수면 시간 범위 안이면 기상 시간만 독립적으로 이동합니다.
        let proposedDuration = sleepDuration(
            from: bedtimeMinutes,
            to: proposedWakeUpMinutes
        )

        if proposedDuration < effectiveMinimumSleepDurationMinutes {
            // 최소 수면 시간보다 좁혀지는 순간부터는 두 핸들이 한 몸처럼 움직입니다.
            // 사용자가 잡고 있는 alarm 핸들은 그대로 따라가고,
            // moon 핸들은 최소 수면 시간만큼 전으로 같이 당겨집니다.
            wakeUpMinutes = proposedWakeUpMinutes
            bedtimeMinutes = normalizedMinutes(proposedWakeUpMinutes - effectiveMinimumSleepDurationMinutes)
        } else if proposedDuration > effectiveMaximumSleepDurationMinutes {
            // 최대 수면 시간보다 길어지는 순간부터도 두 핸들이 한 몸처럼 움직입니다.
            // 사용자가 잡고 있는 alarm 핸들은 그대로 따라가고,
            // moon 핸들은 최대 수면 시간만큼 전 위치로 같이 이동합니다.
            wakeUpMinutes = proposedWakeUpMinutes
            bedtimeMinutes = normalizedMinutes(proposedWakeUpMinutes - effectiveMaximumSleepDurationMinutes)
        } else {
            // 최소~최대 수면 시간 범위 안에서는 다시 각자의 핸들처럼 독립 이동합니다.
            wakeUpMinutes = proposedWakeUpMinutes
        }
    }

    func sleepDuration(from startMinutes: Int, to endMinutes: Int) -> Int {
        // 24시간 원형 다이얼이므로 end가 start보다 작으면 다음 날 시간으로 봅니다.
        // 예: 23:00 -> 07:00 = (420 - 1380 + 1440) % 1440 = 480분입니다.
        (endMinutes - startMinutes + effectiveMinutesPerDay) % effectiveMinutesPerDay
    }

    func normalizedMinutes(_ minutes: Int) -> Int {
        // 음수나 24시간을 넘어간 값을 항상 0~1439 범위로 되돌립니다.
        // Swift의 %는 음수 결과가 나올 수 있어 minutesPerDay를 한 번 더 더합니다.
        Self.normalizedMinutes(minutes, minutesPerDay: effectiveMinutesPerDay)
    }

    static func normalizedMinutes(_ minutes: Int, minutesPerDay: Int) -> Int {
        // init에서도 같은 정규화가 필요해서 static helper로 분리했습니다.
        (minutes % minutesPerDay + minutesPerDay) % minutesPerDay
    }

    func sleepRangePoint(progress: Double, size: CGFloat) -> CGPoint {
        // sleepRangeArcSegment와 같은 원 path 위에 핸들을 올려야
        // 실제 보이는 라운드 캡 위치와 드래그 가능한 위치가 일치합니다.
        // sleepRangeArcSegment에서 사용한 inset 계산을 여기서도 동일하게 사용합니다.
        let inset = rangeStrokeGap + (rangeStrokeWidth / 2)
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

    var totalSleepDurationText: String {
        // 기상 시간이 취침 시간보다 작으면 다음 날 기상으로 봅니다.
        // 예: 23:00 -> 07:00은 (07:00 + 24시간 - 23:00) = 8시간입니다.
        let durationMinutes = sleepDuration(from: bedtimeMinutes, to: wakeUpMinutes)
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60

        return "\(hours)시간 \(minutes)분"
    }

    func timeText(for minutes: Int) -> String {
        let hour24 = minutes / 60
        let minute = minutes % 60
        let period = hour24 < 12 ? "오전" : "오후"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12

        return "\(period) \(hour12):\(String(format: "%02d", minute))"
    }

    func measuredLabelSize(for text: String) -> CGSize {
        // iOS 17 기준 caption + semibold 조합과 같은 UIFont로 텍스트 크기를 계산해
        // SwiftUI Text가 실제로 차지할 영역에 맞춰 위치를 보정합니다.
        let baseFont = UIFont.preferredFont(forTextStyle: .caption1)
        let font = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)

        return CGSize(width: ceil(size.width), height: ceil(size.height))
    }
}
