//
//  ClockHour.swift
//  GabHealthKit
//
//  Created by Gab on 4/22/26.
//

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
