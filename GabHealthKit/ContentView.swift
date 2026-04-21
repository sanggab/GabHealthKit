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
    @State private var statusMessage = "아직 HealthKit 권한을 확인하지 않았습니다."
    @State private var latestStepSummary: HealthKitStepCountModel?
    @State private var latestSleepSummary: HealthKitSleepSummaryModel?
    @State private var alertState: AlertState?

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Button {
                    Task {
                        await requestHealthKitAccess()
                    }
                } label: {
                    Text(isLoading ? "처리 중..." : "헬스킷 권한 요청")
                }
                .disabled(isLoading)

                Button {
                    Task {
                        await fetchHealthSummary()
                    }
                } label: {
                    Text(isLoading ? "조회 준비 중..." : "걸음 수·칼로리·수면 가져오기")
                }
                .disabled(isLoading)

                Text(statusMessage)
                    .multilineTextAlignment(.center)

                if let latestStepSummary {
                    VStack(spacing: 8) {
                        Text("활동 요약")
                            .font(.headline)
                            .foregroundStyle(.black)
                        Text("걸음 수: \(latestStepSummary.stepCount.formatted(.number.precision(.fractionLength(0))))")
                            .foregroundStyle(.black)
                        Text("활동 칼로리: \(latestStepSummary.calories.formatted(.number.precision(.fractionLength(1)))) kcal")
                            .foregroundStyle(.black)
                    }
                }

                if let latestSleepSummary {
                    VStack(spacing: 8) {
                        Text("수면 요약")
                            .font(.headline)
                            .foregroundStyle(.black)
                        Text("총 수면: \(formattedDuration(latestSleepSummary.asleepDuration))")
                            .foregroundStyle(.black)
                        Text("침대에 있던 시간: \(formattedDuration(latestSleepSummary.inBedDuration))")
                            .foregroundStyle(.black)

                        if latestSleepSummary.awakeDuration > 0 {
                            Text("깨어 있던 시간: \(formattedDuration(latestSleepSummary.awakeDuration))")
                                .foregroundStyle(.black)
                        }

                        if latestSleepSummary.asleepCoreDuration > 0 {
                            Text("Core 수면: \(formattedDuration(latestSleepSummary.asleepCoreDuration))")
                                .foregroundStyle(.black)
                        }

                        if latestSleepSummary.asleepDeepDuration > 0 {
                            Text("Deep 수면: \(formattedDuration(latestSleepSummary.asleepDeepDuration))")
                                .foregroundStyle(.black)
                        }

                        if latestSleepSummary.asleepREMDuration > 0 {
                            Text("REM 수면: \(formattedDuration(latestSleepSummary.asleepREMDuration))")
                                .foregroundStyle(.black)
                        }

                        if latestSleepSummary.asleepUnspecifiedDuration > 0 {
                            Text("기타 수면: \(formattedDuration(latestSleepSummary.asleepUnspecifiedDuration))")
                                .foregroundStyle(.black)
                        }
                    }
                }
            }
            .padding(24)
        }
        .alert(item: $alertState) { alertState in
            Alert(
                title: Text(alertState.title),
                message: Text(alertState.message),
                dismissButton: .default(Text("확인"))
            )
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
                latestSleepSummary = nil
                statusMessage = "처음 요청이어서 Apple Health 권한 화면을 띄웠습니다. 걸음 수, 칼로리, 수면 데이터를 보려면 응답 후 다시 조회 버튼을 눌러 주세요."

            case .unnecessary:
                latestStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "Health 권한 화면으로 바로 이동할 수는 없어서 앱 설정만 열고, Health 앱 경로를 함께 안내합니다."
                alertState = AlertState(
                    title: "Health 권한은 건강 앱에서 변경해 주세요",
                    message: "iOS는 앱에서 Health 권한 화면으로 직접 이동하는 공개 API를 제공하지 않습니다. 앱 설정을 열어 드릴게요. Health 권한 자체는 \(healthPermissionManualPath) 경로에서 변경해 주세요."
                )
                openAppSettings()

            case .unknown:
                try await service.requestAuthroization(read: healthSummaryReadTypes)
                latestStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "권한 요청 가능 여부를 미리 판별하진 못했지만 요청을 시도했습니다. 시트가 보이지 않으면 이미 응답한 상태일 수 있습니다."

            @unknown default:
                latestStepSummary = nil
                latestSleepSummary = nil
                statusMessage = "알 수 없는 권한 상태입니다. 잠시 후 다시 시도해 주세요."
            }
        } catch {
            latestStepSummary = nil
            latestSleepSummary = nil
            statusMessage = "권한 요청 중 오류가 발생했습니다."
            alertState = AlertState(
                title: "권한 요청 실패",
                message: error.localizedDescription
            )
        }
    }

    @MainActor
    private func fetchHealthSummary() async {
        isLoading = true

        defer {
            isLoading = false
        }

        let service = HealthKitService.shared

        guard service.isHealthDataAvailable else {
            latestStepSummary = nil
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
                // 조회 전에 권한 상태를 먼저 정리해 두면 Code=5(Authorization not determined)를 피하는 데 도움이 됩니다.
                try await service.requestAuthroization(read: healthSummaryReadTypes)

            case .unnecessary:
                break

            @unknown default:
                break
            }

            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
            async let stepSummary = service.fetchStepCount(from: startDate, to: endDate)
            async let sleepSummary = service.fetchSleepSummary(from: startDate, to: endDate)
            let (stepModel, sleepModel) = try await (stepSummary, sleepSummary)
            print("상갑 logEvent \(#function) stepModel \(stepModel)")
            print("상갑 logEvent \(#function) sleepModel \(sleepModel)")
            latestStepSummary = stepModel
            latestSleepSummary = sleepModel

            if requestStatus == .unnecessary
                && stepModel.stepCount == 0
                && stepModel.calories == 0
                && sleepModel.sampleCount == 0 {
                statusMessage = "최근 7일 조회는 완료했지만 걸음 수, 칼로리, 수면 데이터가 비어 있습니다. 실제 데이터가 없거나 읽기 권한이 꺼져 있을 수 있습니다. HealthKit은 읽기 거부 여부를 앱에 직접 알려주지 않습니다."
            } else {
                statusMessage = "최근 7일의 걸음 수, 칼로리, 수면 조회를 마쳤습니다."
            }
        } catch {
            latestStepSummary = nil
            latestSleepSummary = nil
            statusMessage = "데이터 조회 중 오류가 발생했습니다."
            alertState = AlertState(
                title: "조회 실패",
                message: error.localizedDescription
            )
        }
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
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    ContentView()
}
