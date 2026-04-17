//
//  HealthKitService.swift
//  GabHealthKit
//
//  Created by Gab on 4/17/26.
//

import HealthKit

nonisolated enum HealthKitModel: Hashable, Sendable {
    case stepCount
    case activeEnergyBurned
    case sleepAnalysis

    var objectType: HKObjectType? {
        switch self {
        case .stepCount:
            HKObjectType.quantityType(forIdentifier: .stepCount)
        case .activeEnergyBurned:
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        case .sleepAnalysis:
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        }
    }

    var sampleType: HKSampleType? {
        objectType as? HKSampleType
    }

    var quantityType: HKQuantityType? {
        objectType as? HKQuantityType
    }
}

// 지정한 기간의 걸음 수와 활동 칼로리 합계를 함께 전달하는 모델입니다.
struct HealthKitStepCountModel: Sendable {
    let startDate: Date
    let endDate: Date
    let stepCount: Double
    let calories: Double
}

enum HealthKitServiceError: Error {
    case invalidDateRange
    case unsupportedType(HealthKitModel)
}

final class HealthKitService {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    // 읽기 / 쓰기 권한 요청
    func requestAuthroization(
        write toShare: Set<HealthKitModel> = [],
        read: Set<HealthKitModel>
    ) async throws {
        let shareTypes = Set(toShare.compactMap(\.sampleType))
        let readTypes = Set(read.compactMap(\.objectType))

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    // 원하는 날짜 범위의 걸음 수와 활동 칼로리 합계를 함께 가져옵니다.
    // 두 값 모두 누적형(quantity) 데이터라서 HKStatisticsQuery의 cumulativeSum을 사용합니다.
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> HealthKitStepCountModel {
        guard startDate <= endDate else {
            throw HealthKitServiceError.invalidDateRange
        }

        async let stepCount = fetchCumulativeSum(
            for: .stepCount,
            unit: .count(),
            from: startDate,
            to: endDate
        )
        async let calories = fetchCumulativeSum(
            for: .activeEnergyBurned,
            unit: .kilocalorie(),
            from: startDate,
            to: endDate
        )

        return try await HealthKitStepCountModel(
            startDate: startDate,
            endDate: endDate,
            stepCount: stepCount,
            calories: calories
        )
    }

    // 누적형 HealthKit quantity 데이터를 날짜 범위 기준으로 합산합니다.
    // 여기서는 걸음 수와 활동 칼로리처럼 total 값을 구할 때 공통으로 사용합니다.
    private func fetchCumulativeSum(
        for model: HealthKitModel,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        guard let quantityType = model.quantityType else {
            throw HealthKitServiceError.unsupportedType(model)
        }

        // 요청한 시작/종료 시간 안에 완전히 포함된 샘플만 합산합니다.
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let totalValue = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: totalValue)
            }

            healthStore.execute(query)
        }
    }

    // 원하는 날짜 범위와 겹치는 수면 분석 샘플을 가져옵니다.
    // sleepAnalysis는 category 샘플 데이터라서 HKSampleQuery로 원본 샘플 목록을 그대로 읽어옵니다.
    func fetchSleepAnalysis(from startDate: Date, to endDate: Date) async throws -> [HKCategorySample] {
        guard startDate <= endDate else {
            throw HealthKitServiceError.invalidDateRange
        }

        guard let sleepAnalysisType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitServiceError.unsupportedType(.sleepAnalysis)
        }

        // 수면 데이터는 자정을 넘기는 경우가 많아서 범위와 겹치는 샘플도 포함하도록 strict 옵션을 비웁니다.
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )
        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        ]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepAnalysisType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sortDescriptors
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sleepSamples = samples as? [HKCategorySample] ?? []
                continuation.resume(returning: sleepSamples)
            }

            healthStore.execute(query)
        }
    }
}

//// 걸음 수(stepCount)를 읽고 쓰기 위한 HealthKit 타입입니다.
//private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
//
//// 앱이 HealthKit에 기록(write)하려는 샘플 타입 목록입니다.
//private var appTypes: Set<HKSampleType> {
//    [
//        stepCountType
//    ]
//}
//
//// 앱이 HealthKit에서 읽기(read)하려는 데이터 타입 목록입니다.
//private var readTypes: Set<HKObjectType> {
//    [stepCountType]
//}
//
//// HealthKit 권한 요청과 조회 실행에 사용하는 저장소 객체입니다.
//let healthStore = HKHealthStore()


//// 이번 조회에서도 동일하게 걸음 수 샘플만 가져옵니다.
//let sampleType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
//
//// 오늘 시점을 기준으로 최근 7일 범위를 조회합니다.
//let endDate = Date()
//let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
//
//// startDate 이상, endDate 이하에 시작한 샘플만 조회합니다.
//let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
//
//// 걸음 수 샘플을 비동기로 받아오는 HealthKit 쿼리입니다.
//let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 0, sortDescriptors: nil) { _, results, error in
//    print("상갑 logEvent \(#function) error \(String(describing: error))")
//
//    // 이번 예제에서는 수치형 샘플만 사용하므로 HKQuantitySample 배열로 변환합니다.
//    guard let samples = results as? [HKQuantitySample] else {
//        print("상갑 logEvent \(#function)")
//        return
//    }
//
//    // 각 샘플의 값, 타입, 식별자, 시간 범위를 확인하기 위한 디버그 로그입니다.
//    samples.forEach {
//        print("상갑 logEvent ================================================================================")
//        // 실제 측정값은 quantity.doubleValue(for: .count())로 숫자로 변환해서 볼 수 있습니다.
//        print("상갑 logEvent \(#function) $0.quantity \($0.quantity)")
//        // 이 샘플이 어떤 HealthKit 타입인지(stepCount 등)를 나타냅니다.
//        print("상갑 logEvent \(#function) $0.quantityType \($0.quantityType)")
//        // HealthKit 내부에서 샘플을 구분하는 고유 식별자입니다.
//        print("상갑 logEvent \(#function) $0.uuid \($0.uuid)")
//        // 해당 샘플이 시작된 시각입니다.
//        print("상갑 logEvent \(#function) $0.startDate \($0.startDate)")
//        // 해당 샘플이 종료된 시각입니다.
//        print("상갑 logEvent \(#function) $0.endDate \($0.endDate)")
//        // 샘플 개념상의 count이며, 실제 걸음 수 값과는 다른 의미입니다.
//        print("상갑 logEvent \(#function) $0.count \($0.count)")
//        print("상갑 logEvent ================================================================================")
//    }
//    
//    // TODO: 가져온 샘플을 화면 상태나 누적 통계에 연결할 수 있습니다.
//}
//
//// 구성한 쿼리를 HealthKit에 전달해 실제 조회를 시작합니다.
//healthStore.execute(query)
