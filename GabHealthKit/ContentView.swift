//
//  ContentView.swift
//  GabHealthKit
//
//  Created by Gab on 4/15/26.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    private let healthSummaryReadTypes: Set<HealthKitModel> = [.stepCount, .activeEnergyBurned, .sleepAnalysis]
    private let healthPermissionManualPath = "건강 앱 > 프로필 사진 > 개인정보 보호 > 앱 > GabHealthKit"

    @Environment(\.openURL) private var openURL

    @State private var isLoading = false
    @State private var statusMessage = "선택한 날짜의 걸음 수와 수면 기록을 함께 확인해 보세요."
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var latestStepSummary: HealthKitStepCountModel?
    @State private var previousDayStepSummary: HealthKitStepCountModel?
    @State private var latestHealthSleepEntry: SleepDisplayEntry?
    @State private var lastAuthorizationRequestStatus: HKAuthorizationRequestStatus?
    @State private var isSleepSheetPresented = false
    @State private var sleepDraft = SleepDraft.defaultValue(for: Calendar.current.startOfDay(for: Date()))
    @State private var manualSleepEntries = ManualSleepEntryStore.load()
    @State private var alertState: AlertState?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                weekCalendarSection
                statusBanner
                sleepCardSection
                stepCardSection
                actionButtonsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.99).ignoresSafeArea())
        .alert(item: $alertState) { alertState in
            switch alertState.kind {
            case .info:
                Alert(
                    title: Text(alertState.title),
                    message: Text(alertState.message),
                    dismissButton: .default(Text("확인"))
                )

            case .settingsConfirmation:
                Alert(
                    title: Text(alertState.title),
                    message: Text(alertState.message),
                    primaryButton: .cancel(Text("취소")),
                    secondaryButton: .default(Text("권한 허용하기"), action: openAppSettings)
                )
            }
        }
        .sheet(isPresented: $isSleepSheetPresented) {
            sleepBottomSheet
                .presentationDetents([.height(620)])
                .presentationDragIndicator(.visible)
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("기록")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)

                Text(selectedDate.formatted(.dateTime.year().month().day().weekday(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.6))

                Text("수면은 직접 기록 또는 Health 데이터 중 더 우선인 값으로 보여줘요")
                    .font(.footnote)
                    .foregroundStyle(Color.black.opacity(0.45))
            }

            Spacer()

            VStack(spacing: 10) {
                headerActionButton(
                    title: "권한",
                    systemImage: "heart.text.square.fill",
                    foregroundColor: .white,
                    backgroundColor: Color(red: 0.2, green: 0.26, blue: 0.39),
                    showBorder: false
                ) {
                    Task {
                        await requestHealthKitAccess()
                    }
                }

                headerActionButton(
                    title: isLoading ? "불러오는 중" : "새로고침",
                    systemImage: "arrow.clockwise",
                    foregroundColor: Color(red: 0.2, green: 0.26, blue: 0.39),
                    backgroundColor: .white,
                    showBorder: true
                ) {
                    Task {
                        await fetchHealthSummary(for: selectedDate)
                    }
                }
                .disabled(isLoading)
            }
        }
    }

    private var weekCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 7일")
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.45))

            HStack(spacing: 10) {
                ForEach(recentWeekDates, id: \.self) { date in
                    Button {
                        selectedDate = date

                        if latestStepSummary != nil || latestHealthSleepEntry != nil || hasManualSleepEntry(for: date) {
                            Task {
                                await fetchHealthSummary(for: date)
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2)
                                .fontWeight(.semibold)

                            Text(date.formatted(.dateTime.day()))
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .foregroundStyle(isSelected(date) ? .white : Color.black.opacity(0.72))
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(isSelected(date) ? Color(red: 0.2, green: 0.26, blue: 0.39) : .white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.black.opacity(isSelected(date) ? 0 : 0.06), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(isSelected(date) ? 0.16 : 0.04), radius: 14, y: 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statusBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isLoading ? "clock.arrow.circlepath" : "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(Color(red: 0.33, green: 0.45, blue: 0.82))

            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(Color.black.opacity(0.72))
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
    }

    private var sleepCardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("수면")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)

                    Text(selectedDate.formatted(.dateTime.month().day()) + " 기준 수면 기록")
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.45))
                }

                Spacer()

                if let displayedSleepEntry {
                    sourceBadge(for: displayedSleepEntry.source)
                }
            }

            HStack(spacing: 16) {
                sleepSummaryIllustration

                if let displayedSleepEntry {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text(formattedDuration(displayedSleepEntry.duration))
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .minimumScaleFactor(0.7)

                            Text("수면 기록")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.5))
                        }

                        Text("취침 \(formattedTime(displayedSleepEntry.startDate)) · 기상 \(formattedTime(displayedSleepEntry.endDate))")
                            .font(.subheadline)
                            .foregroundStyle(Color.black.opacity(0.72))

                        Text(displayedSleepEntry.source == .manual ? "직접 입력한 값이 Health 데이터보다 우선 적용되고 있어요" : "Health 데이터에서 자동으로 읽어온 수면 기록이에요")
                            .font(.footnote)
                            .foregroundStyle(Color.black.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(shouldShowSleepConnectCTA ? "수면 기록을 시작해볼까요?" : "아직 수면 기록이 없어요")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.black)

                        Text(shouldShowSleepConnectCTA ? "직접 입력하거나 Health 데이터를 연동하면 선택한 날짜의 수면 시간을 바로 확인할 수 있어요" : "선택한 날짜에는 아직 표시할 수면 데이터가 없어요. 카드나 아래 버튼으로 직접 기록을 남길 수 있어요")
                            .font(.subheadline)
                            .foregroundStyle(Color.black.opacity(0.56))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if shouldShowSleepConnectCTA {
                Button {
                    Task {
                        await requestHealthKitAccess()
                    }
                } label: {
                    Text(isLoading ? "확인 중..." : "데이터 연동하기")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.36, green: 0.31, blue: 0.97))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .dashboardCardStyle()
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            presentSleepSheet()
        }
    }

    private var stepCardSection: some View {
        Group {
            if let latestStepSummary {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("걸음 수")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.black)

                            Text("선택한 날짜의 활동량을 보여줘요")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.45))
                        }

                        Spacer()

                        Image(systemName: "figure.walk.motion")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.98, green: 0.67, blue: 0.23))
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color(red: 1, green: 0.95, blue: 0.85))
                            )
                    }

                    HStack(spacing: 18) {
                        stepCircle(stepCount: latestStepSummary.stepCount)

                        VStack(alignment: .leading, spacing: 12) {
                            metricRow(
                                title: "총 걸음 수",
                                value: formattedWholeNumber(latestStepSummary.stepCount),
                                tint: Color(red: 0.2, green: 0.26, blue: 0.39)
                            )

                            if let comparisonMessage = stepComparisonMessage(current: latestStepSummary.stepCount) {
                                Text(comparisonMessage)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(stepComparisonColor(current: latestStepSummary.stepCount))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            metricRow(
                                title: "활동 소모 칼로리",
                                value: "\(formattedWholeNumber(latestStepSummary.calories)) kcal",
                                tint: Color(red: 0.18, green: 0.58, blue: 0.89)
                            )
                        }
                    }
                }
                .dashboardCardStyle()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("걸음 수")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)

                    Text("선택한 날짜의 활동량을 보려면 Health 데이터를 먼저 불러와 주세요")
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .dashboardCardStyle()
            }
        }
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button {
                presentSleepSheet()
            } label: {
                Label("수면 기록", systemImage: "bed.double.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.2, green: 0.26, blue: 0.39))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white)
                    )
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await fetchHealthSummary(for: selectedDate)
                }
            } label: {
                Label(isLoading ? "불러오는 중" : "데이터 가져오기", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(red: 0.2, green: 0.26, blue: 0.39))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
    }

    private var sleepBottomSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("수면")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.black)

                    Text("취침 시간과 기상 시간을 조절해 수면 시간을 기록해 보세요")
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.52))
                }

                Spacer()

                sheetIconControl {
                    isSleepSheetPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.black.opacity(0.55))
                        .padding(10)
                        .background(Circle().fill(Color.black.opacity(0.04)))
                }
            }

            HStack(spacing: 12) {
                sleepTimeEditorCard(title: "취침 시간", icon: "moon.fill", tint: Color(red: 0.43, green: 0.38, blue: 0.95), selection: $sleepDraft.startDate)
                sleepTimeEditorCard(title: "기상 시간", icon: "sun.max.fill", tint: Color(red: 0.98, green: 0.67, blue: 0.23), selection: $sleepDraft.endDate)
            }

            sleepScheduleDial(for: selectedDate)

            VStack(alignment: .leading, spacing: 8) {
                Text("저장 기준")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)

                Text("저장하면 선택한 날짜의 직접 입력 기록이 즉시 반영되고, 이후에는 Health 데이터보다 우선해서 보여줘요.")
                    .font(.footnote)
                    .foregroundStyle(Color.black.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)
            }

            sheetPrimaryAction {
                saveSleepDraft()
            } label: {
                Text("저장")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(Color.white)
    }

    private var displayedSleepEntry: SleepDisplayEntry? {
        if let manualEntry = manualSleepEntries[sleepEntryKey(for: selectedDate)] {
            return SleepDisplayEntry(
                startDate: manualEntry.startDate,
                endDate: manualEntry.endDate,
                duration: manualEntry.endDate.timeIntervalSince(manualEntry.startDate),
                source: .manual
            )
        }

        return latestHealthSleepEntry
    }

    private var shouldShowSleepConnectCTA: Bool {
        guard displayedSleepEntry == nil else {
            return false
        }

        switch lastAuthorizationRequestStatus {
        case .unnecessary:
            return false

        default:
            return true
        }
    }

    private var sleepSummaryIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.96, blue: 1.0),
                            Color(red: 0.97, green: 0.95, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 12)
                .padding(18)

            VStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.97))

                Text(displayedSleepEntry == nil ? "-시간\n--분" : formattedDuration(displayedSleepEntry?.duration ?? 0))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 138, height: 138)
    }

    private var recentWeekDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (-6...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func sleepEntryKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func hasManualSleepEntry(for date: Date) -> Bool {
        manualSleepEntries[sleepEntryKey(for: date)] != nil
    }

    @ViewBuilder
    private func headerActionButton(
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color,
        showBorder: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Capsule().fill(backgroundColor))
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(showBorder ? 0.06 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sourceBadge(for source: SleepDataSource) -> some View {
        Text(source == .manual ? "직접 입력" : "Health 연동")
            .font(.caption.weight(.semibold))
            .foregroundStyle(source == .manual ? Color(red: 0.36, green: 0.31, blue: 0.97) : Color(red: 0.18, green: 0.58, blue: 0.89))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((source == .manual ? Color(red: 0.94, green: 0.92, blue: 1.0) : Color(red: 0.91, green: 0.97, blue: 1.0)))
            )
    }

    @ViewBuilder
    private func sleepTimeEditorCard(
        title: String,
        icon: String,
        tint: Color,
        selection: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.52))

            Text(formattedTime(selection.wrappedValue))
                .font(.title3.weight(.bold))
                .foregroundStyle(.black)

            Text("다이얼 핸들로 조절")
                .font(.footnote)
                .foregroundStyle(tint.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.98, green: 0.99, blue: 1.0))
        )
    }

    @ViewBuilder
    private func sheetIconControl<Label: View>(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        label()
            .contentShape(Circle())
            .onTapGesture(perform: action)
    }

    @ViewBuilder
    private func sheetPrimaryAction<Label: View>(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        label()
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture(perform: action)
    }

    @ViewBuilder
    private func sleepScheduleDial(for selectedDate: Date) -> some View {
        let draft = sleepDraft
        let resolvedDuration = draft.resolvedInterval(for: selectedDate)?.duration ?? 0
        let startAngle = sleepSliderAngle(for: draft.startDate)
        let endAngle = sleepSliderAngle(for: draft.endDate)
        let startProgress = CGFloat(startAngle / 360)
        let endProgress = CGFloat(endAngle / 360)
        let reverseRotation = startProgress > endProgress ? -Double((1 - startProgress) * 360) : 0
        let hourMarkers = [12, 15, 18, 21, 0, 3, 6, 9]

        VStack(spacing: 18) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let handleOffset = (size / 2) - 4

                ZStack {
                    ZStack {
                        ForEach(hourMarkers.indices, id: \.self) { index in
                            Text("\(hourMarkers[index])")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.black.opacity(0.4))
                                .rotationEffect(.degrees(Double(index) * -45))
                                .offset(y: (size - 92) / 2)
                                .rotationEffect(.degrees(Double(index) * 45))
                        }
                    }

                    Circle()
                        .stroke(Color(red: 0.92, green: 0.91, blue: 0.98), lineWidth: 34)

                    Circle()
                        .trim(
                            from: startProgress > endProgress ? 0 : startProgress,
                            to: endProgress + CGFloat(-reverseRotation / 360)
                        )
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.81, green: 0.72, blue: 1.0),
                                    Color(red: 0.36, green: 0.31, blue: 0.97)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .rotationEffect(.degrees(reverseRotation))

                    VStack(spacing: 8) {
                        Text(formattedDuration(resolvedDuration))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)

                        Text("총 수면 시간")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.5))

                        Text("핸들을 드래그해 취침·기상 시간을 조절하세요")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.38))
                    }

                    sleepSliderHandleIcon(systemName: "moon.fill", tint: Color(red: 0.36, green: 0.31, blue: 0.97))
                        .rotationEffect(.degrees(90))
                        .rotationEffect(.degrees(-startAngle))
                        .offset(x: handleOffset)
                        .rotationEffect(.degrees(startAngle))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    sleepDraft.startDate = updatedDialDate(
                                        from: value,
                                        basedOn: sleepDraft.startDate
                                    )
                                }
                        )
                        .rotationEffect(.degrees(-90))

                    sleepSliderHandleIcon(systemName: "sun.max.fill", tint: Color(red: 0.98, green: 0.67, blue: 0.23))
                        .rotationEffect(.degrees(90))
                        .rotationEffect(.degrees(-endAngle))
                        .offset(x: handleOffset)
                        .rotationEffect(.degrees(endAngle))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    sleepDraft.endDate = updatedDialDate(
                                        from: value,
                                        basedOn: sleepDraft.endDate
                                    )
                                }
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(height: 268)

            Text("자동으로 읽은 값이 있으면 먼저 채워 두고, 원하면 직접 수정해서 저장할 수 있어요")
                .font(.footnote)
                .foregroundStyle(Color.black.opacity(0.52))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.98, green: 0.99, blue: 1.0))
        )
    }

    @ViewBuilder
    private func markerIcon(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(
                Circle()
                    .fill(Color.white)
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func sleepSliderHandleIcon(systemName: String, tint: Color) -> some View {
        markerIcon(systemName: systemName, tint: tint)
            .frame(width: 64, height: 64)
            .contentShape(Circle())
    }

    @ViewBuilder
    private func stepCircle(stepCount: Double) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.95, blue: 1.0),
                            Color(red: 0.98, green: 0.91, blue: 0.79)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 12)
                .padding(10)

            VStack(spacing: 6) {
                Text(formattedWholeNumber(stepCount))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.7)

                Text("걸음")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 148, height: 148)
    }

    @ViewBuilder
    private func metricRow(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.45))

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    @MainActor
    private func requestHealthKitAccess() async {
        isLoading = true

        defer {
            isLoading = false
        }

        let service = HealthKitService.shared

        guard service.isHealthDataAvailable else {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestHealthSleepEntry = nil
            statusMessage = "이 기기에서는 HealthKit을 사용할 수 없습니다."
            alertState = AlertState(
                title: "HealthKit 사용 불가",
                message: "이 기기 또는 현재 환경에서는 HealthKit 데이터를 사용할 수 없습니다."
            )
            return
        }

        do {
            let requestStatus = try await service.authorizationRequestStatus(read: healthSummaryReadTypes)
            lastAuthorizationRequestStatus = requestStatus

            switch requestStatus {
            case .shouldRequest:
                try await service.requestAuthroization(read: healthSummaryReadTypes)
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestHealthSleepEntry = nil
                statusMessage = "처음 요청이어서 Apple Health 권한 화면을 띄웠습니다. 응답 후 데이터 가져오기를 눌러 최신 기록을 불러와 주세요."

            case .unnecessary:
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestHealthSleepEntry = nil
                statusMessage = "이미 응답한 권한입니다. 원하면 앱 설정으로 이동해 다시 권한 경로를 안내해 드릴게요."
                alertState = AlertState(
                    title: "Health 권한은 건강 앱에서 변경해 주세요",
                    message: "iOS는 앱에서 Health 권한 화면으로 직접 이동하는 공개 API를 제공하지 않습니다. 앱 설정으로 이동하시겠어요? Health 권한 자체는 \(healthPermissionManualPath) 경로에서 변경해 주세요.",
                    kind: .settingsConfirmation
                )

            case .unknown:
                try await service.requestAuthroization(read: healthSummaryReadTypes)
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestHealthSleepEntry = nil
                statusMessage = "권한 요청 가능 여부를 미리 판별하진 못했지만 요청을 시도했습니다. 시트가 보이지 않으면 이미 응답한 상태일 수 있습니다."

            @unknown default:
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestHealthSleepEntry = nil
                statusMessage = "알 수 없는 권한 상태입니다. 잠시 후 다시 시도해 주세요."
            }
        } catch {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestHealthSleepEntry = nil
            statusMessage = "권한 요청 중 오류가 발생했습니다."
            alertState = AlertState(
                title: "권한 요청 실패",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func fetchHealthSummary(for date: Date) async {
        isLoading = true
        selectedDate = Calendar.current.startOfDay(for: date)

        defer {
            isLoading = false
        }

        let service = HealthKitService.shared

        guard service.isHealthDataAvailable else {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestHealthSleepEntry = nil
            statusMessage = "이 기기에서는 HealthKit을 사용할 수 없습니다."
            alertState = AlertState(
                title: "HealthKit 사용 불가",
                message: "이 기기 또는 현재 환경에서는 HealthKit 데이터를 사용할 수 없습니다."
            )
            return
        }

        do {
            let requestStatus = try await service.authorizationRequestStatus(read: healthSummaryReadTypes)
            lastAuthorizationRequestStatus = requestStatus

            switch requestStatus {
            case .shouldRequest, .unknown:
                try await service.requestAuthroization(read: healthSummaryReadTypes)

            case .unnecessary:
                break

            @unknown default:
                break
            }

            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: selectedDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let previousDayStart = calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart

            let sleepWindowStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
            let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: dayEnd) ?? dayEnd

            async let stepSummary = service.fetchStepCount(from: dayStart, to: dayEnd)
            async let previousStepSummary = service.fetchStepCount(from: previousDayStart, to: dayStart)
            async let sleepSummary = service.fetchSleepSummary(from: sleepWindowStart, to: sleepWindowEnd)
            async let sleepAnalysis = service.fetchSleepAnalysis(from: sleepWindowStart, to: sleepWindowEnd)

            let (stepModel, previousModel, sleepModel, sleepSamples) = try await (stepSummary, previousStepSummary, sleepSummary, sleepAnalysis)
            latestStepSummary = stepModel
            previousDayStepSummary = previousModel
            latestHealthSleepEntry = buildHealthSleepEntry(summary: sleepModel, samples: sleepSamples, fallbackDate: dayStart)

            if requestStatus == .unnecessary
                && stepModel.stepCount == 0
                && stepModel.calories == 0
                && latestHealthSleepEntry == nil
                && hasManualSleepEntry(for: dayStart) == false {
                statusMessage = "선택한 날짜 조회는 완료했지만 데이터가 비어 있습니다. 실제 기록이 없거나 읽기 권한이 꺼져 있을 수 있습니다. HealthKit은 읽기 거부 여부를 앱에 직접 알려주지 않습니다."
            } else {
                statusMessage = "\(selectedDate.formatted(.dateTime.month().day())) 활동과 수면 기록을 불러왔습니다."
            }
        } catch {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestHealthSleepEntry = nil
            statusMessage = "데이터 조회 중 오류가 발생했습니다."
            alertState = AlertState(
                title: "조회 실패",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func presentSleepSheet() {
        sleepDraft = currentSleepDraft(for: selectedDate)
        isSleepSheetPresented = true
    }

    @MainActor
    private func saveSleepDraft() {
        guard let resolvedInterval = sleepDraft.resolvedInterval(for: selectedDate) else {
            alertState = AlertState(
                title: "수면 시간 확인",
                message: "수면 시간을 계산하지 못했습니다. 시간을 다시 선택해 주세요."
            )
            return
        }

        guard resolvedInterval.duration > 0 else {
            alertState = AlertState(
                title: "수면 시간 확인",
                message: "기상 시간은 취침 시간보다 나중이어야 합니다."
            )
            return
        }

        let key = sleepEntryKey(for: selectedDate)
        manualSleepEntries[key] = ManualSleepEntry(startDate: resolvedInterval.startDate, endDate: resolvedInterval.endDate)
        ManualSleepEntryStore.save(manualSleepEntries)
        sleepDraft = SleepDraft(startDate: resolvedInterval.startDate, endDate: resolvedInterval.endDate)
        statusMessage = "\(selectedDate.formatted(.dateTime.month().day())) 수면 기록을 직접 저장했습니다."
        isSleepSheetPresented = false
    }

    private func currentSleepDraft(for date: Date) -> SleepDraft {
        if let manualEntry = manualSleepEntries[sleepEntryKey(for: date)] {
            return SleepDraft(startDate: manualEntry.startDate, endDate: manualEntry.endDate)
        }

        if let latestHealthSleepEntry, isSelected(date) {
            return SleepDraft(startDate: latestHealthSleepEntry.startDate, endDate: latestHealthSleepEntry.endDate)
        }

        return SleepDraft.defaultValue(for: date)
    }

    private func buildHealthSleepEntry(
        summary: HealthKitSleepSummaryModel,
        samples: [HKCategorySample],
        fallbackDate: Date
    ) -> SleepDisplayEntry? {
        guard summary.asleepDuration > 0 else {
            return nil
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        let asleepSamples = samples.filter { asleepValues.contains($0.value) }

        if let representativeSession = representativeSleepSession(from: asleepSamples, for: fallbackDate) {
            return SleepDisplayEntry(
                startDate: representativeSession.startDate,
                endDate: representativeSession.endDate,
                duration: representativeSession.asleepDuration,
                source: .health
            )
        }

        let fallbackEndDate = Calendar.current.date(byAdding: .hour, value: 7, to: fallbackDate) ?? fallbackDate
        let fallbackStartDate = fallbackEndDate.addingTimeInterval(-summary.asleepDuration)

        return SleepDisplayEntry(
            startDate: fallbackStartDate,
            endDate: fallbackEndDate,
            duration: summary.asleepDuration,
            source: .health
        )
    }

    private func sleepSliderAngle(for date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let totalMinutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        return (totalMinutes / (24 * 60)) * 360
    }

    private func updatedDialDate(from value: DragGesture.Value, basedOn originalDate: Date) -> Date {
        let handleHalfSize = 32.0
        let vector = CGVector(dx: value.location.x, dy: value.location.y)
        var degrees = atan2(vector.dy - handleHalfSize, vector.dx - handleHalfSize) * 180 / .pi

        if degrees < 0 {
            degrees += 360
        }

        return dialDate(for: degrees, basedOn: originalDate)
    }

    private func dialDate(for angle: Double, basedOn originalDate: Date) -> Date {
        let minutesPerDay = 24 * 60
        let rawMinutes = (angle / 360) * Double(minutesPerDay)
        let snappedMinutes = Int((rawMinutes / 5).rounded() * 5)
        let wrappedMinutes = snappedMinutes % minutesPerDay
        let normalizedMinutes = wrappedMinutes >= 0 ? wrappedMinutes : wrappedMinutes + minutesPerDay
        let hour = normalizedMinutes / 60
        let minute = normalizedMinutes % 60

        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: originalDate) ?? originalDate
    }

    private func stepComparisonMessage(current stepCount: Double) -> String? {
        guard let previousDayStepSummary, previousDayStepSummary.stepCount > 0 else {
            return nil
        }

        let difference = stepCount - previousDayStepSummary.stepCount
        let formattedDifference = formattedWholeNumber(abs(difference))

        if difference > 0 {
            return "어제보다 \(formattedDifference)걸음 더 걸었어요"
        }

        if difference < 0 {
            return "어제보다 \(formattedDifference)걸음 적게 걸었어요"
        }

        return "어제와 비슷하게 걸었어요"
    }

    private func stepComparisonColor(current stepCount: Double) -> Color {
        guard let previousDayStepSummary else {
            return Color.black.opacity(0.62)
        }

        let difference = stepCount - previousDayStepSummary.stepCount

        if difference > 0 {
            return Color(red: 0.17, green: 0.62, blue: 0.36)
        }

        if difference < 0 {
            return Color(red: 0.84, green: 0.34, blue: 0.31)
        }

        return Color.black.opacity(0.62)
    }

    private func formattedWholeNumber(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2

        return formatter.string(from: duration) ?? "0분"
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func representativeSleepSession(from samples: [HKCategorySample], for selectedDate: Date) -> SleepSession? {
        let mergedSegments = mergedSleepSegments(from: samples)
        guard mergedSegments.isEmpty == false else {
            return nil
        }

        let groupedSessions = groupedSleepSessions(from: mergedSegments)
        guard groupedSessions.isEmpty == false else {
            return nil
        }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let targetInterval = DateInterval(start: dayStart, end: dayEnd)

        return groupedSessions.max { lhs, rhs in
            let lhsOverlap = overlapDuration(between: lhs.interval, and: targetInterval)
            let rhsOverlap = overlapDuration(between: rhs.interval, and: targetInterval)

            if lhsOverlap != rhsOverlap {
                return lhsOverlap < rhsOverlap
            }

            if lhs.asleepDuration != rhs.asleepDuration {
                return lhs.asleepDuration < rhs.asleepDuration
            }

            return lhs.endDate > rhs.endDate
        }
    }

    private func mergedSleepSegments(from samples: [HKCategorySample]) -> [DateInterval] {
        let sortedSamples = samples.sorted {
            if $0.startDate == $1.startDate {
                return $0.endDate < $1.endDate
            }

            return $0.startDate < $1.startDate
        }

        guard let firstSample = sortedSamples.first else {
            return []
        }

        var mergedIntervals: [DateInterval] = []
        var currentInterval = DateInterval(start: firstSample.startDate, end: firstSample.endDate)

        for sample in sortedSamples.dropFirst() {
            if sample.startDate <= currentInterval.end {
                currentInterval = DateInterval(start: currentInterval.start, end: max(currentInterval.end, sample.endDate))
            } else {
                mergedIntervals.append(currentInterval)
                currentInterval = DateInterval(start: sample.startDate, end: sample.endDate)
            }
        }

        mergedIntervals.append(currentInterval)
        return mergedIntervals
    }

    private func groupedSleepSessions(from segments: [DateInterval]) -> [SleepSession] {
        guard let firstSegment = segments.first else {
            return []
        }

        let allowedGap: TimeInterval = 90 * 60
        var sessions: [SleepSession] = []
        var currentSession = SleepSession(
            startDate: firstSegment.start,
            endDate: firstSegment.end,
            asleepDuration: firstSegment.duration
        )

        for segment in segments.dropFirst() {
            if segment.start.timeIntervalSince(currentSession.endDate) <= allowedGap {
                currentSession = SleepSession(
                    startDate: currentSession.startDate,
                    endDate: max(currentSession.endDate, segment.end),
                    asleepDuration: currentSession.asleepDuration + segment.duration
                )
            } else {
                sessions.append(currentSession)
                currentSession = SleepSession(
                    startDate: segment.start,
                    endDate: segment.end,
                    asleepDuration: segment.duration
                )
            }
        }

        sessions.append(currentSession)
        return sessions
    }

    private func overlapDuration(between lhs: DateInterval, and rhs: DateInterval) -> TimeInterval {
        let overlapStart = max(lhs.start, rhs.start)
        let overlapEnd = min(lhs.end, rhs.end)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }

    @MainActor
    private func openAppSettings() {
        guard let url = URL(string: "app-settings:") else {
            alertState = AlertState(
                title: "설정 열기 실패",
                message: "설정 페이지 주소를 만들지 못했습니다."
            )
            return
        }

        openURL(url) { accepted in
            if accepted == false {
                alertState = AlertState(
                    title: "설정 열기 실패",
                    message: "설정 앱을 열지 못했습니다. Health 권한은 \(healthPermissionManualPath) 경로에서 직접 확인해 주세요."
                )
            }
        }
    }
}

private struct AlertState: Identifiable {
    enum Kind {
        case info
        case settingsConfirmation
    }

    let id = UUID()
    let title: String
    let message: String
    var kind: Kind = .info
}

private enum SleepDataSource {
    case manual
    case health
}

private struct SleepDisplayEntry {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let source: SleepDataSource
}

private struct SleepDraft {
    var startDate: Date
    var endDate: Date

    func resolvedInterval(for selectedDate: Date, calendar: Calendar = .current) -> SleepSession? {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startDate)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endDate)

        guard let startHour = startComponents.hour,
              let startMinute = startComponents.minute,
              let endHour = endComponents.hour,
              let endMinute = endComponents.minute,
              let sameDayStart = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: dayStart),
              let sameDayEnd = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: dayStart) else {
            return nil
        }

        let resolvedStart: Date
        let resolvedEnd: Date

        if sameDayStart <= sameDayEnd {
            resolvedStart = sameDayStart
            resolvedEnd = sameDayEnd
        } else {
            resolvedStart = calendar.date(byAdding: .day, value: -1, to: sameDayStart) ?? sameDayStart
            resolvedEnd = sameDayEnd
        }

        return SleepSession(
            startDate: resolvedStart,
            endDate: resolvedEnd,
            asleepDuration: resolvedEnd.timeIntervalSince(resolvedStart)
        )
    }

    static func defaultValue(for selectedDate: Date) -> SleepDraft {
        let calendar = Calendar.current
        let wakeDate = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        let previousDay = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        let sleepDate = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: previousDay) ?? previousDay
        return SleepDraft(startDate: sleepDate, endDate: wakeDate)
    }
}

private struct ManualSleepEntry: Codable {
    let startDate: Date
    let endDate: Date
}

private struct SleepSession {
    let startDate: Date
    let endDate: Date
    let asleepDuration: TimeInterval

    var interval: DateInterval {
        DateInterval(start: startDate, end: endDate)
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

private enum ManualSleepEntryStore {
    static let key = "manualSleepEntries"

    static func load() -> [String: ManualSleepEntry] {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return [:]
        }

        return (try? JSONDecoder().decode([String: ManualSleepEntry].self, from: data)) ?? [:]
    }

    static func save(_ entries: [String: ManualSleepEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key)
    }
}

private extension View {
    func dashboardCardStyle() -> some View {
        self
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: .black.opacity(0.06), radius: 22, y: 12)
    }
}

#Preview {
    ContentView()
}
