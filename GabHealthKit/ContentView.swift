//
//  ContentView.swift
//  GabHealthKit
//
//  Created by Gab on 4/15/26.
//

import SwiftUI
import HealthKit

struct ContentView: View {
    // 걸음 수 요약 조회는 stepCount와 activeEnergyBurned 읽기 권한을 함께 사용합니다.
    private let stepSummaryReadTypes: Set<HealthKitModel> = [.stepCount, .activeEnergyBurned]

    var body: some View {
        ZStack {
            Color.white
            
            VStack {
                Button {
                    Task {
                        do {
                            try await HealthKitService.shared.requestAuthroization(read: stepSummaryReadTypes)
                        } catch {
                            print("상갑 logEvent \(#function) error \(error)")
                        }
                    }
                } label: {
                    Text("헬스킷 권한 요청")
                }
                
                Button {
                    Task {
                        do {
                            // 조회 전에 권한 상태를 먼저 결정해야 Code=5(Authorization not determined)를 피할 수 있습니다.
                            try await HealthKitService.shared.requestAuthroization(read: stepSummaryReadTypes)

                            let calendar = Calendar.current
                            let startDate = calendar.startOfDay(for: Date())
                            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
                             
                            let model = try await HealthKitService.shared.fetchStepCount(from: startDate, to: endDate)
                            
                            print("상갑 logEvent \(#function) model \(model)")
                        } catch {
                            print("상갑 logEvent \(#function) error \(error)")
                        }
                    }
                } label: {
                    Text("걸음 수 및 칼로리 가져오기")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
