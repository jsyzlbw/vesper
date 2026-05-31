import Testing
@testable import DiaryCompanionCore

@Test func defaultPolicyRequiresConfirmation() {
    let policy = ToolPermissionPolicy()
    #expect(policy.decision(for: .createTask) == .confirm)
}

@Test func automaticCapabilityAllowsNormalWrite() {
    var policy = ToolPermissionPolicy()
    policy.capabilityModes[.task] = .automatic
    #expect(policy.decision(for: .createTask) == .allow)
}

@Test func deniedCapabilityRejectsWrite() {
    var policy = ToolPermissionPolicy()
    policy.capabilityModes[.medication] = .denied
    #expect(policy.decision(for: .updateMedication) == .deny)
}

@Test func highRiskToolStillRequiresConfirmation() {
    var policy = ToolPermissionPolicy()
    policy.capabilityModes[.diary] = .automatic
    #expect(policy.decision(for: .deleteDiaryEntry) == .confirm)
}
