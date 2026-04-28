//
//  SleepDialogView.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

import SwiftUI

struct SleepDialogView: View {
    // 바인딩 없이 사용할 때 내부에서 보관하는 기본 상태입니다.
    @State private var localBedtimeMinutes: Int
    @State private var localWakeUpMinutes: Int

    // 부모가 값을 직접 제어하고 싶을 때 사용하는 외부 바인딩입니다.
    private let externalBedtimeMinutes: Binding<Int>?
    private let externalWakeUpMinutes: Binding<Int>?

    // 외부에서 바꿀 수 있는 값은 시간 정책과 스타일만 남겨 API를 단순화합니다.
    let policy: Policy
    let style: Style

    // 다이얼을 따라 배치할 시간 목록입니다.
    let times: [ClockHour]

    init(
        policy: Policy = Policy(),
        style: Style = Style(),
        times: [ClockHour] = ClockHour.allCases
    ) {
        self.policy = policy
        self.style = style
        self.times = times
        self.externalBedtimeMinutes = nil
        self.externalWakeUpMinutes = nil
        self._localBedtimeMinutes = State(initialValue: Self.normalizedMinutes(policy.initialBedtimeMinutes, minutesPerDay: max(1, policy.minutesPerDay)))
        self._localWakeUpMinutes = State(initialValue: Self.normalizedMinutes(policy.initialWakeUpMinutes, minutesPerDay: max(1, policy.minutesPerDay)))
    }

    init(
        bedtimeMinutes: Binding<Int>,
        wakeUpMinutes: Binding<Int>,
        policy: Policy = Policy(),
        style: Style = Style(),
        times: [ClockHour] = ClockHour.allCases
    ) {
        self.policy = policy
        self.style = style
        self.times = times
        self.externalBedtimeMinutes = bedtimeMinutes
        self.externalWakeUpMinutes = wakeUpMinutes
        self._localBedtimeMinutes = State(initialValue: Self.normalizedMinutes(bedtimeMinutes.wrappedValue, minutesPerDay: max(1, policy.minutesPerDay)))
        self._localWakeUpMinutes = State(initialValue: Self.normalizedMinutes(wakeUpMinutes.wrappedValue, minutesPerDay: max(1, policy.minutesPerDay)))
    }

    private var bedtimeMinutesBinding: Binding<Int> {
        externalBedtimeMinutes ?? $localBedtimeMinutes
    }

    private var wakeUpMinutesBinding: Binding<Int> {
        externalWakeUpMinutes ?? $localWakeUpMinutes
    }

    var bedtimeMinutes: Int {
        get { normalizedMinutes(bedtimeMinutesBinding.wrappedValue) }
        nonmutating set {
            bedtimeMinutesBinding.wrappedValue = normalizedMinutes(newValue)
        }
    }

    var wakeUpMinutes: Int {
        get { normalizedMinutes(wakeUpMinutesBinding.wrappedValue) }
        nonmutating set {
            wakeUpMinutesBinding.wrappedValue = normalizedMinutes(newValue)
        }
    }

    var effectiveMinutesPerDay: Int {
        max(1, policy.minutesPerDay)
    }

    var effectiveMinuteSnapInterval: Int {
        max(1, policy.minuteSnapInterval)
    }

    var effectiveMinimumSleepDurationMinutes: Int {
        max(0, min(policy.minimumSleepDurationMinutes, effectiveMinutesPerDay))
    }

    var effectiveMaximumSleepDurationMinutes: Int {
        max(
            effectiveMinimumSleepDurationMinutes,
            min(policy.maximumSleepDurationMinutes, effectiveMinutesPerDay)
        )
    }

    // 이 값들은 화면 기본 레이아웃/텍스트/치수 정책이라 외부 커스텀 대상에서 제외합니다.
    let summaryTopPadding: CGFloat = 50
    let bedtimeTitle = "취침 시간"
    let wakeUpTitle = "기상 시간"
    let summaryPrimaryColor = Color.white
    let summarySecondaryColor = Color.white.opacity(0.75)
    let totalTickSlots = 48
    let majorTickSlotInterval = 4
    let tickWidth: CGFloat = 3
    let majorTickHeight: CGFloat = 15
    let minorTickHeight: CGFloat = 8
    let tickInset: CGFloat = 5
    let tickLabelGap: CGFloat = 10
    let tickColor = Color.white
    let minorTickOpacity = 0.9
    let rangeStrokeWidth: CGFloat = 30
    let rangeStrokeGap: CGFloat = 5
    let handleHitSize: CGFloat = 44
    let handleIconSize: CGFloat = 20
    
    var body: some View {
        GeometryReader { proxy in
            // 현재 화면이 허용하는 실제 영역 안에서 가장 큰 정사각형을 다이얼 크기로 사용합니다.
            let dialSize = min(proxy.size.width, proxy.size.height)
            let safeTotalTickSlots = max(1, totalTickSlots)
            let safeMajorTickSlotInterval = max(1, majorTickSlotInterval)

            ZStack(alignment: .center) {
                ZStack {
                    // 원형 다이얼 배경입니다.
                    Circle()
                        .fill(style.dialBackgroundColor)

                    ForEach(0..<safeTotalTickSlots, id: \.self) { index in
                        // 시간 눈금이 그려지는 자리는 분금을 중복으로 그리지 않습니다.
                        if index % safeMajorTickSlotInterval != 0 {
                            dialMinorTick(
                                angle: Double(index) * (360 / Double(safeTotalTickSlots)),
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
                    .strokeBorder(style.borderColor, lineWidth: style.borderWidth)
                    .frame(width: dialSize, height: dialSize)

                sleepRangeArc(size: dialSize)
                
                if style.showsCenterImage, let centerImageURL = style.centerImageURL {
                    AsyncImage(url: centerImageURL) { result in
                        result.image?
                            .resizable()
                    }
                    .frame(width: style.centerImageSize.width, height: style.centerImageSize.height)
                }

                sleepSummaryPanel
                    .padding(.top, summaryTopPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                
            }
            // GeometryReader가 제공한 전체 영역을 모두 사용합니다.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(style.screenBackgroundColor)
        }
    }

    private var sleepSummaryPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 24) {
                sleepTimeSummary(
                    systemName: style.bedtimeIconSystemName,
                    title: bedtimeTitle,
                    time: timeText(for: bedtimeMinutes)
                )

                sleepTimeSummary(
                    systemName: style.wakeUpIconSystemName,
                    title: wakeUpTitle,
                    time: timeText(for: wakeUpMinutes)
                )
            }

            Text(totalSleepDurationText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(summaryPrimaryColor)
        }
    }

    private func sleepTimeSummary(systemName: String, title: String, time: String) -> some View {
        VStack(spacing: 4) {
            Label(title, systemImage: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(summarySecondaryColor)

            Text(time)
                .font(.title3.weight(.bold))
                .foregroundStyle(summaryPrimaryColor)
                .monospacedDigit()
        }
    }
}

#Preview {
    // SwiftUI Preview에서 다이얼 배치를 바로 확인할 수 있는 진입점입니다.
    SleepDialogView()
}
