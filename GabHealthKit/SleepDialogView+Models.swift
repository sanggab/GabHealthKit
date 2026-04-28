//
//  SleepDialogView+Models.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import Foundation
import SwiftUI

extension SleepDialogView {
    struct Policy {
        // 바인딩 없이 SleepDialogView()로 사용할 때 적용할 기본 시간입니다.
        // 외부에서 Binding을 넣는 경우에는 부모가 가진 값이 우선됩니다.
        var initialBedtimeMinutes = 23 * 60
        var initialWakeUpMinutes = 7 * 60

        // 24시간 다이얼이므로 하루 전체 분 수를 기준으로 progress와 시간을 서로 변환합니다.
        var minutesPerDay = 24 * 60

        // 드래그로 시간이 바뀔 때 이 단위로만 갱신되도록 스냅합니다.
        var minuteSnapInterval = 5

        // 취침/기상 핸들이 서로 너무 가까워지면 최소 수면 구간을 유지합니다.
        var minimumSleepDurationMinutes = 60

        // 수면 시간이 너무 길어지면 최대 수면 구간을 유지합니다.
        var maximumSleepDurationMinutes = 20 * 60
    }

    struct Style {
        // 다이얼 전체 색상과 선택 아크 표현입니다.
        var dialBackgroundColor = Color.blue
        var screenBackgroundColor = Color.black.opacity(0.9)
        var borderColor = Color.black.opacity(1)
        var borderWidth: CGFloat = 40
        var rangeColor = Color.mint

        // 핸들 표현입니다.
        var bedtimeIconSystemName = "moon.stars.fill"
        var wakeUpIconSystemName = "alarm.fill"

        // 중앙 이미지입니다. url을 nil로 두거나 isVisible을 false로 두면 이미지를 그리지 않습니다.
        var showsCenterImage = true
        var centerImageURL = URL(string: "https://blog.treasurer.co.kr/assets/img/treasurer/rolex/rolex_12.png")
        var centerImageSize = CGSize(width: 100, height: 100)
    }
}
