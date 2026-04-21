//
//  ContentView.swift
//  GabHealthKit
//
//  Created by Gab on 4/15/26.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    // 통합 요약 조회는 걸음 수, 활동 칼로리, 수면 읽기 권한을 함께 사용합니다.
    private let healthSummaryReadTypes: Set<HealthKitModel> = [.stepCount, .activeEnergyBurned, .sleepAnalysis]
    private let healthPermissionManualPath = "건강 앱 > 프로필 사진 > 개인정보 보호 > 앱 > GabHealthKit"

    @Environment(\.openURL) private var openURL

    @State private var isLoading = false
    @State private var statusMessage = "HealthKit을 연결하면 걸음 수와 수면 기록을 한 화면에서 볼 수 있어요."
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var latestStepSummary: HealthKitStepCountModel?
    @State private var previousDayStepSummary: HealthKitStepCountModel?
    @State private var latestSleepSummary: HealthKitSleepSummaryModel?
    @State private var alertState: AlertState?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                weekCalendarSection
                statusBanner
                stepCardSection
                sleepCardSection
                actionButtonsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.99).ignoresSafeArea())
        .alert(item: $alertState) { alertState in
            Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                dismissButton: .default(Text("확인"))
            )
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

                Text("선택한 날짜의 활동과 최근 7일 수면을 함께 확인해 보세요")
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

                        if latestStepSummary != nil || latestSleepSummary != nil {
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

    private var stepCardSection: some View {
        Group {
            if let latestStepSummary {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("걸음 수")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.black)

                            Text("메인 수치는 선택한 날짜 기준으로 보여줘요")
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("오늘은 얼마나 걸었을까요?")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.black)

                        Text("건강데이터를 연결하면 걸음 수와 소모 칼로리를 함께 볼 수 있어요")
                            .font(.subheadline)
                            .foregroundStyle(Color.black.opacity(0.56))
                    }

                    Button {
                        Task {
                            await requestHealthKitAccess()
                        }
                    } label: {
                        Text(isLoading ? "확인 중..." : "연동하기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(red: 0.2, green: 0.26, blue: 0.39))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .dashboardCardStyle()
            }
        }
    }

    private var sleepCardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("수면 & 컨디션")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black)

                    Text("최근 7일 기준으로 수면 요약을 보여줘요")
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.45))
                }

                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.45, green: 0.52, blue: 0.95))
                    .padding(12)
                    .background(
                        Circle()
                            .fill(Color(red: 0.91, green: 0.93, blue: 1.0))
                    )
            }

            if let latestSleepSummary {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(formattedDuration(latestSleepSummary.asleepDuration))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)

                        Text("총 수면")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black.opacity(0.45))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        sleepMetricCard(title: "침대에 있던 시간", value: formattedDuration(latestSleepSummary.inBedDuration), tint: Color(red: 0.31, green: 0.57, blue: 0.96))
                        sleepMetricCard(title: "깨어 있던 시간", value: formattedDuration(latestSleepSummary.awakeDuration), tint: Color(red: 0.98, green: 0.67, blue: 0.23))

                        if latestSleepSummary.asleepCoreDuration > 0 {
                            sleepMetricCard(title: "Core 수면", value: formattedDuration(latestSleepSummary.asleepCoreDuration), tint: Color(red: 0.42, green: 0.68, blue: 0.95))
                        }

                        if latestSleepSummary.asleepDeepDuration > 0 {
                            sleepMetricCard(title: "Deep 수면", value: formattedDuration(latestSleepSummary.asleepDeepDuration), tint: Color(red: 0.34, green: 0.39, blue: 0.91))
                        }

                        if latestSleepSummary.asleepREMDuration > 0 {
                            sleepMetricCard(title: "REM 수면", value: formattedDuration(latestSleepSummary.asleepREMDuration), tint: Color(red: 0.72, green: 0.46, blue: 0.96))
                        }

                        if latestSleepSummary.asleepUnspecifiedDuration > 0 {
                            sleepMetricCard(title: "기타 수면", value: formattedDuration(latestSleepSummary.asleepUnspecifiedDuration), tint: Color(red: 0.56, green: 0.62, blue: 0.72))
                        }
                    }
                }
            } else {
                Text("수면 데이터를 아직 불러오지 않았어요. 새로고침을 누르면 최근 7일 수면 기록을 함께 확인할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.56))
            }
        }
        .dashboardCardStyle()
    }

    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await requestHealthKitAccess()
                }
            } label: {
                Label("권한 확인", systemImage: "lock.shield")
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
            .disabled(isLoading)

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
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(showBorder ? 0.06 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private func sleepMetricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.48))

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.98, green: 0.99, blue: 1.0))
        )
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
            latestSleepSummary = nil
            statusMessage = "이 기기에서는 HealthKit을 사용할 수 없습니다."
            alertState = AlertState(
                title: "HealthKit 사용 불가",
                message: "이 기기 또는 현재 환경에서는 HealthKit 데이터를 사용할 수 없습니다."
            )
            return
        }

        do {
            let requestStatus = try await service.authorizationRequestStatus(read: healthSummaryReadTypes)

            switch requestStatus {
            case .shouldRequest:
                try await service.requestAuthroization(read: healthSummaryReadTypes)
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "처음 요청이어서 Apple Health 권한 화면을 띄웠습니다. 응답 후 데이터 가져오기를 눌러 최신 기록을 불러와 주세요."

            case .unnecessary:
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "이미 응답한 권한이라 앱 설정을 열어 드립니다. Health 권한 자체는 건강 앱 경로에서 변경해 주세요."
                alertState = AlertState(
                    title: "Health 권한은 건강 앱에서 변경해 주세요",
                    message: "iOS는 앱에서 Health 권한 화면으로 직접 이동하는 공개 API를 제공하지 않습니다. 앱 설정을 열어 드릴게요. Health 권한 자체는 \(healthPermissionManualPath) 경로에서 변경해 주세요."
                )
                openAppSettings()

            case .unknown:
                try await service.requestAuthroization(read: healthSummaryReadTypes)
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "권한 요청 가능 여부를 미리 판별하진 못했지만 요청을 시도했습니다. 시트가 보이지 않으면 이미 응답한 상태일 수 있습니다."

            @unknown default:
                latestStepSummary = nil
                previousDayStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "알 수 없는 권한 상태입니다. 잠시 후 다시 시도해 주세요."
            }
        } catch {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestSleepSummary = nil
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
            latestSleepSummary = nil
            statusMessage = "이 기기에서는 HealthKit을 사용할 수 없습니다."
            alertState = AlertState(
                title: "HealthKit 사용 불가",
                message: "이 기기 또는 현재 환경에서는 HealthKit 데이터를 사용할 수 없습니다."
            )
            return
        }

        do {
            let requestStatus = try await service.authorizationRequestStatus(read: healthSummaryReadTypes)

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
            let sleepWindowStart = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart

            async let stepSummary = service.fetchStepCount(from: dayStart, to: dayEnd)
            async let previousStepSummary = service.fetchStepCount(from: previousDayStart, to: dayStart)
            async let sleepSummary = service.fetchSleepSummary(from: sleepWindowStart, to: dayEnd)

            let (stepModel, previousModel, sleepModel) = try await (stepSummary, previousStepSummary, sleepSummary)
            latestStepSummary = stepModel
            previousDayStepSummary = previousModel
            latestSleepSummary = sleepModel
            print("상갑 logEvent \(#function) ============================================================")
            print("상갑 logEvent \(#function) stepModel \(stepModel)")
            print("상갑 logEvent \(#function) previousModel \(previousModel)")
            print("상갑 logEvent \(#function) sleepModel \(sleepModel)")
            print("상갑 logEvent \(#function) ============================================================")

            if requestStatus == .unnecessary
                && stepModel.stepCount == 0
                && stepModel.calories == 0
                && sleepModel.sampleCount == 0 {
                statusMessage = "선택한 날짜와 최근 7일 조회는 완료했지만 데이터가 비어 있습니다. 실제 데이터가 없거나 읽기 권한이 꺼져 있을 수 있습니다. HealthKit은 읽기 거부 여부를 앱에 직접 알려주지 않습니다."
            } else {
                statusMessage = "\(selectedDate.formatted(.dateTime.month().day())) 활동 기록과 최근 7일 수면 요약을 불러왔습니다."
            }
        } catch {
            latestStepSummary = nil
            previousDayStepSummary = nil
            latestSleepSummary = nil
            statusMessage = "데이터 조회 중 오류가 발생했습니다."
            alertState = AlertState(
                title: "조회 실패",
                message: error.localizedDescription
            )
        }
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

    @MainActor
    private func openAppSettings() {
        guard let url = URL(string: "x-apple-health://Summary") else {
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
    let id = UUID()
    let title: String
    let message: String
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
