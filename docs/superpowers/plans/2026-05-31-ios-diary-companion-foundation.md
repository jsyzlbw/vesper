# iOS Diary Companion Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first offline-capable iOS Diary Companion foundation: a simulator-launchable SwiftUI shell plus a tested Swift package for models, permissions, provider presets, Keychain storage, and local reminder request construction.

**Architecture:** Keep reusable behavior in `DiaryCompanionCore`, a local Swift package that can be tested quickly with `swift test`. The `DiaryCompanion` iOS target stays thin: it owns SwiftUI navigation and imports the package. CloudKit entitlements, real provider networking, streaming chat, and persistent notification scheduling are deferred to later plans because they require separate behavior slices and, for CloudKit, a signed Apple capability configuration.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, Foundation, Security, UserNotifications, Xcode 26.5, iOS Simulator 26.5

---

## File Structure

```text
.gitignore
DiaryCompanion.xcodeproj/
└── project.pbxproj
DiaryCompanion/
├── DiaryCompanionApp.swift
└── RootTabView.swift
DiaryCompanionCore/
├── Package.swift
├── Sources/
│   └── DiaryCompanionCore/
│       ├── DiaryCompanionCore.swift
│       ├── Models/
│       │   ├── DiaryModels.swift
│       │   └── ProviderProfile.swift
│       ├── Notifications/
│       │   └── ReminderRequestFactory.swift
│       ├── Permissions/
│       │   └── ToolPermissionPolicy.swift
│       └── Security/
│           └── KeychainStore.swift
└── Tests/
    └── DiaryCompanionCoreTests/
        ├── DiaryCompanionCoreTests.swift
        ├── KeychainStoreTests.swift
        ├── ProviderPresetTests.swift
        ├── ReminderRequestFactoryTests.swift
        └── ToolPermissionPolicyTests.swift
```

## Task 1: Repository hygiene and buildable scaffold

**Files:**
- Create: `.gitignore`
- Create: `DiaryCompanionCore/Package.swift`
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/DiaryCompanionCore.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryCompanionCoreTests.swift`
- Create: `DiaryCompanion/DiaryCompanionApp.swift`
- Create: `DiaryCompanion/RootTabView.swift`
- Create: `DiaryCompanion.xcodeproj/project.pbxproj`

- [ ] **Step 1: Ignore generated and local-only files**

Create `.gitignore`:

```gitignore
.DS_Store
.worktrees/
.build/
DerivedData/
*.xcuserstate
xcuserdata/
logs/
```

- [ ] **Step 2: Create the package manifest**

Create `DiaryCompanionCore/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiaryCompanionCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "DiaryCompanionCore", targets: ["DiaryCompanionCore"]),
    ],
    targets: [
        .target(name: "DiaryCompanionCore"),
        .testTarget(
            name: "DiaryCompanionCoreTests",
            dependencies: ["DiaryCompanionCore"]
        ),
    ]
)
```

- [ ] **Step 3: Create the SwiftUI shell**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/DiaryCompanionCore.swift`:

```swift
public enum DiaryCompanionCoreModule {}
```

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryCompanionCoreTests.swift`:

```swift
import Testing
```

Create `DiaryCompanion/DiaryCompanionApp.swift`:

```swift
import SwiftUI

@main
struct DiaryCompanionApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
```

Create `DiaryCompanion/RootTabView.swift`:

```swift
import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView(
                    "开始对话",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("连接 AI Provider 后，通过自然语言记录生活。")
                )
                .navigationTitle("对话")
            }
            .tabItem {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
            }

            NavigationStack {
                ContentUnavailableView(
                    "暂无记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("AI 保存的日记、任务和总结会出现在这里。")
                )
                .navigationTitle("时间线")
            }
            .tabItem {
                Label("时间线", systemImage: "clock")
            }

            NavigationStack {
                List {
                    Section("AI Provider") {
                        Text("尚未配置")
                    }
                    Section("权限") {
                        Text("默认执行前确认")
                    }
                }
                .navigationTitle("设置")
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }

            NavigationStack {
                ContentUnavailableView(
                    "暂无审计记录",
                    systemImage: "checklist",
                    description: Text("AI 的工具调用记录会显示在这里。")
                )
                .navigationTitle("审计")
            }
            .tabItem {
                Label("审计", systemImage: "checklist")
            }
        }
    }
}

#Preview {
    RootTabView()
}
```

- [ ] **Step 4: Create the Xcode project**

Create `DiaryCompanion.xcodeproj/project.pbxproj` with one iOS application target named `DiaryCompanion`, two Swift source files, and the local package product `DiaryCompanionCore`. Use:

```text
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 60;
	objects = {

/* Begin PBXBuildFile section */
		AA0000000000000000000001 /* DiaryCompanionApp.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA0000000000000000000011 /* DiaryCompanionApp.swift */; };
		AA0000000000000000000002 /* RootTabView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA0000000000000000000012 /* RootTabView.swift */; };
		AA0000000000000000000003 /* DiaryCompanionCore in Frameworks */ = {isa = PBXBuildFile; productRef = AA0000000000000000000041 /* DiaryCompanionCore */; };
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		AA0000000000000000000010 /* DiaryCompanion.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DiaryCompanion.app; sourceTree = BUILT_PRODUCTS_DIR; };
		AA0000000000000000000011 /* DiaryCompanionApp.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = DiaryCompanionApp.swift; sourceTree = "<group>"; };
		AA0000000000000000000012 /* RootTabView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RootTabView.swift; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		AA0000000000000000000021 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000000003 /* DiaryCompanionCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		AA0000000000000000000030 = {
			isa = PBXGroup;
			children = (
				AA0000000000000000000031 /* DiaryCompanion */,
				AA0000000000000000000032 /* Products */,
			);
			sourceTree = "<group>";
		};
		AA0000000000000000000031 /* DiaryCompanion */ = {
			isa = PBXGroup;
			children = (
				AA0000000000000000000011 /* DiaryCompanionApp.swift */,
				AA0000000000000000000012 /* RootTabView.swift */,
			);
			path = DiaryCompanion;
			sourceTree = "<group>";
		};
		AA0000000000000000000032 /* Products */ = {
			isa = PBXGroup;
			children = (
				AA0000000000000000000010 /* DiaryCompanion.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		AA0000000000000000000040 /* DiaryCompanion */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA0000000000000000000071 /* Build configuration list for PBXNativeTarget "DiaryCompanion" */;
			buildPhases = (
				AA0000000000000000000020 /* Sources */,
				AA0000000000000000000021 /* Frameworks */,
				AA0000000000000000000022 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = DiaryCompanion;
			packageProductDependencies = (
				AA0000000000000000000041 /* DiaryCompanionCore */,
			);
			productName = DiaryCompanion;
			productReference = AA0000000000000000000010 /* DiaryCompanion.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		AA0000000000000000000050 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2650;
				LastUpgradeCheck = 2650;
				TargetAttributes = {
					AA0000000000000000000040 = {
						CreatedOnToolsVersion = 26.5;
					};
				};
			};
			buildConfigurationList = AA0000000000000000000070 /* Build configuration list for PBXProject "DiaryCompanion" */;
			compatibilityVersion = "Xcode 15.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = AA0000000000000000000030;
			packageReferences = (
				AA0000000000000000000090 /* XCLocalSwiftPackageReference "DiaryCompanionCore" */,
			);
			productRefGroup = AA0000000000000000000032 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				AA0000000000000000000040 /* DiaryCompanion */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		AA0000000000000000000022 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		AA0000000000000000000020 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA0000000000000000000001 /* DiaryCompanionApp.swift in Sources */,
				AA0000000000000000000002 /* RootTabView.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		AA0000000000000000000060 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ENABLE_MODULES = YES;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		AA0000000000000000000061 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CLANG_ENABLE_MODULES = YES;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
			};
			name = Release;
		};
		AA0000000000000000000062 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = DiaryCompanion;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.liangbowenbill.DiaryCompanion;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Debug;
		};
		AA0000000000000000000063 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = DiaryCompanion;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = com.liangbowenbill.DiaryCompanion;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 1;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		AA0000000000000000000070 /* Build configuration list for PBXProject "DiaryCompanion" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA0000000000000000000060 /* Debug */,
				AA0000000000000000000061 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA0000000000000000000071 /* Build configuration list for PBXNativeTarget "DiaryCompanion" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA0000000000000000000062 /* Debug */,
				AA0000000000000000000063 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		AA0000000000000000000090 /* XCLocalSwiftPackageReference "DiaryCompanionCore" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = DiaryCompanionCore;
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		AA0000000000000000000041 /* DiaryCompanionCore */ = {
			isa = XCSwiftPackageProductDependency;
			productName = DiaryCompanionCore;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = AA0000000000000000000050 /* Project object */;
}
```

- [ ] **Step 5: Verify the package and app scaffold**

Run:

```bash
swift test --package-path DiaryCompanionCore
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: package exits `0`, then Xcode reports `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add .gitignore DiaryCompanion DiaryCompanion.xcodeproj DiaryCompanionCore/Package.swift DiaryCompanionCore/Sources/DiaryCompanionCore/DiaryCompanionCore.swift DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryCompanionCoreTests.swift
git commit -m "build: scaffold iOS diary companion"
```

## Task 2: Provider profiles and presets

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Models/ProviderProfile.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderPresetTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ProviderPresetTests.swift`:

```swift
import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func presetsIncludeRequiredProviders() {
    #expect(Set(ProviderPreset.allCases.map(\.id)) == [
        "openai", "anthropic", "gemini", "deepseek", "siliconflow", "custom",
    ])
}

@Test func deepSeekUsesOpenAICompatibleProtocol() {
    #expect(ProviderPreset.deepSeek.protocolKind == .openAICompatible)
    #expect(ProviderPreset.deepSeek.defaultBaseURL?.absoluteString == "https://api.deepseek.com")
}

@Test func siliconFlowUsesOpenAICompatibleProtocol() {
    #expect(ProviderPreset.siliconFlow.protocolKind == .openAICompatible)
    #expect(ProviderPreset.siliconFlow.defaultBaseURL?.absoluteString == "https://api.siliconflow.cn/v1")
}

@Test func customProfilePreservesUserConfiguration() throws {
    let profile = ProviderProfile(
        displayName: "Campus Proxy",
        preset: .custom,
        baseURL: try #require(URL(string: "https://example.com/v1")),
        modelName: "example-model",
        isEnabled: true
    )

    #expect(profile.displayName == "Campus Proxy")
    #expect(profile.protocolKind == .openAICompatible)
    #expect(profile.baseURL.absoluteString == "https://example.com/v1")
    #expect(profile.modelName == "example-model")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ProviderPresetTests
```

Expected: FAIL because `ProviderPreset` and `ProviderProfile` do not exist.

- [ ] **Step 3: Implement provider profiles**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Models/ProviderProfile.swift`:

```swift
import Foundation

public enum ProviderProtocolKind: String, Codable, CaseIterable, Sendable {
    case openAI
    case anthropic
    case gemini
    case openAICompatible
}

public enum ProviderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case anthropic
    case gemini
    case deepSeek
    case siliconFlow
    case custom

    public var id: String {
        switch self {
        case .openAI: "openai"
        case .anthropic: "anthropic"
        case .gemini: "gemini"
        case .deepSeek: "deepseek"
        case .siliconFlow: "siliconflow"
        case .custom: "custom"
        }
    }

    public var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .deepSeek: "DeepSeek"
        case .siliconFlow: "硅基流动"
        case .custom: "Custom"
        }
    }

    public var protocolKind: ProviderProtocolKind {
        switch self {
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .gemini: .gemini
        case .deepSeek, .siliconFlow, .custom: .openAICompatible
        }
    }

    public var defaultBaseURL: URL? {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1")
        case .anthropic: URL(string: "https://api.anthropic.com/v1")
        case .gemini: URL(string: "https://generativelanguage.googleapis.com/v1beta")
        case .deepSeek: URL(string: "https://api.deepseek.com")
        case .siliconFlow: URL(string: "https://api.siliconflow.cn/v1")
        case .custom: nil
        }
    }
}

public struct ProviderProfile: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var preset: ProviderPreset
    public var baseURL: URL
    public var modelName: String
    public var isEnabled: Bool

    public var protocolKind: ProviderProtocolKind {
        preset.protocolKind
    }

    public init(
        id: UUID = UUID(),
        displayName: String,
        preset: ProviderPreset,
        baseURL: URL,
        modelName: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.preset = preset
        self.baseURL = baseURL
        self.modelName = modelName
        self.isEnabled = isEnabled
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ProviderPresetTests
```

Expected: PASS with `4 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: add AI provider presets"
```

## Task 3: Tool permission policy

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Permissions/ToolPermissionPolicy.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ToolPermissionPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ToolPermissionPolicyTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ToolPermissionPolicyTests
```

Expected: FAIL because `ToolPermissionPolicy` does not exist.

- [ ] **Step 3: Implement the permission policy**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Permissions/ToolPermissionPolicy.swift`:

```swift
import Foundation

public enum ToolCapability: String, Codable, CaseIterable, Sendable {
    case diary
    case task
    case reminder
    case weight
    case meal
    case medication
    case summary
}

public enum ToolPermissionMode: String, Codable, CaseIterable, Sendable {
    case automatic
    case confirm
    case denied
}

public enum ToolPermissionDecision: Codable, Equatable, Sendable {
    case allow
    case confirm
    case deny
}

public enum DiaryTool: String, Codable, CaseIterable, Sendable {
    case createDiaryEntry
    case updateDiaryEntry
    case deleteDiaryEntry
    case recordWeight
    case recordMeal
    case updateMedication
    case createTask
    case completeTask
    case scheduleReminder
    case generateDailySummary

    public var capability: ToolCapability {
        switch self {
        case .createDiaryEntry, .updateDiaryEntry, .deleteDiaryEntry: .diary
        case .recordWeight: .weight
        case .recordMeal: .meal
        case .updateMedication: .medication
        case .createTask, .completeTask: .task
        case .scheduleReminder: .reminder
        case .generateDailySummary: .summary
        }
    }

    public var isHighRisk: Bool {
        self == .deleteDiaryEntry
    }
}

public struct ToolPermissionPolicy: Codable, Equatable, Sendable {
    public var capabilityModes: [ToolCapability: ToolPermissionMode]

    public init(
        capabilityModes: [ToolCapability: ToolPermissionMode] = [:]
    ) {
        self.capabilityModes = capabilityModes
    }

    public func decision(for tool: DiaryTool) -> ToolPermissionDecision {
        let mode = capabilityModes[tool.capability] ?? .confirm
        if mode == .denied {
            return .deny
        }
        if tool.isHighRisk {
            return .confirm
        }
        return mode == .automatic ? .allow : .confirm
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ToolPermissionPolicyTests
```

Expected: PASS with `4 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: add configurable tool permissions"
```

## Task 4: Keychain storage

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Security/KeychainStore.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/KeychainStoreTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/KeychainStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func storesLoadsAndDeletesSecret() throws {
    let service = "DiaryCompanionCoreTests.\(UUID().uuidString)"
    let store = KeychainStore(service: service)
    defer { try? store.delete(account: "openai") }

    try store.save("test-secret", account: "openai")
    #expect(try store.load(account: "openai") == "test-secret")

    try store.delete(account: "openai")
    #expect(try store.load(account: "openai") == nil)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter KeychainStoreTests
```

Expected: FAIL because `KeychainStore` does not exist.

- [ ] **Step 3: Implement Keychain storage**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Security/KeychainStore.swift`:

```swift
import Foundation
import Security

public struct KeychainStore: Sendable {
    private let service: String

    public init(service: String = "com.liangbowenbill.DiaryCompanion") {
        self.service = service
    }

    public func save(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandled(status)
        }
    }

    public func load(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess,
              let data = item as? Data,
              let secret = String(data: data, encoding: .utf8)
        else {
            throw KeychainStoreError.unhandled(status)
        }
        return secret
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandled(status)
        }
    }
}

public enum KeychainStoreError: Error, Equatable {
    case unhandled(OSStatus)
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter KeychainStoreTests
```

Expected: PASS with `1 test passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: store provider secrets in Keychain"
```

## Task 5: Reminder notification request factory

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRequestFactoryTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/ReminderRequestFactoryTests.swift`:

```swift
import Foundation
import Testing
import UserNotifications
@testable import DiaryCompanionCore

@Test func buildsCalendarNotificationRequest() throws {
    let date = try #require(
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 6, day: 1, hour: 20, minute: 0)
        )
    )
    let request = ReminderRequestFactory().makeRequest(
        id: "medication-1",
        title: "吃药提醒",
        body: "记得吃药",
        fireDate: date
    )

    #expect(request.identifier == "medication-1")
    #expect(request.content.title == "吃药提醒")
    #expect(request.content.body == "记得吃药")

    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == false)
    #expect(trigger.dateComponents.hour == 20)
    #expect(trigger.dateComponents.minute == 0)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactoryTests
```

Expected: FAIL because `ReminderRequestFactory` does not exist.

- [ ] **Step 3: Implement reminder request construction**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Notifications/ReminderRequestFactory.swift`:

```swift
import Foundation
import UserNotifications

public struct ReminderRequestFactory: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func makeRequest(
        id: String,
        title: String,
        body: String,
        fireDate: Date
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter ReminderRequestFactoryTests
```

Expected: PASS with `1 test passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: build local reminder requests"
```

## Task 6: Core diary models

**Files:**
- Create: `DiaryCompanionCore/Sources/DiaryCompanionCore/Models/DiaryModels.swift`
- Create: `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryModelsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DiaryCompanionCore/Tests/DiaryCompanionCoreTests/DiaryModelsTests.swift`:

```swift
import Foundation
import Testing
@testable import DiaryCompanionCore

@Test func diaryEntryTracksSourceMessage() {
    let messageID = UUID()
    let entry = DiaryEntry(
        date: Date(timeIntervalSince1970: 0),
        content: "今天完成了项目设计。",
        tags: ["工作"],
        sourceMessageID: messageID
    )
    #expect(entry.sourceMessageID == messageID)
    #expect(entry.tags == ["工作"])
}

@Test func auditLogRedactsSensitiveKeys() {
    let log = ToolAuditLog(
        toolName: "configureProvider",
        parameters: [
            "provider": "openai",
            "apiKey": "sk-secret",
            "Authorization": "Bearer secret",
        ],
        decision: .allow,
        result: .success
    )
    #expect(log.parameterSummary["provider"] == "openai")
    #expect(log.parameterSummary["apiKey"] == "<redacted>")
    #expect(log.parameterSummary["Authorization"] == "<redacted>")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter DiaryModelsTests
```

Expected: FAIL because `DiaryEntry` and `ToolAuditLog` do not exist.

- [ ] **Step 3: Implement the core value models**

Create `DiaryCompanionCore/Sources/DiaryCompanionCore/Models/DiaryModels.swift`:

```swift
import Foundation

public struct DiaryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var date: Date
    public var content: String
    public var tags: [String]
    public var sourceMessageID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        content: String,
        tags: [String] = [],
        sourceMessageID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.tags = tags
        self.sourceMessageID = sourceMessageID
    }
}

public enum ToolExecutionResult: String, Codable, Equatable, Sendable {
    case success
    case failure
    case denied
}

public struct ToolAuditLog: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let toolName: String
    public let parameterSummary: [String: String]
    public let decision: ToolPermissionDecision
    public let result: ToolExecutionResult
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        toolName: String,
        parameters: [String: String],
        decision: ToolPermissionDecision,
        result: ToolExecutionResult,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolName = toolName
        self.parameterSummary = Dictionary(
            uniqueKeysWithValues: parameters.map { key, value in
                let normalized = key.lowercased()
                let isSensitive = normalized.contains("apikey")
                    || normalized.contains("authorization")
                    || normalized.contains("token")
                    || normalized.contains("secret")
                return (key, isSensitive ? "<redacted>" : value)
            }
        )
        self.decision = decision
        self.result = result
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --package-path DiaryCompanionCore --filter DiaryModelsTests
```

Expected: PASS with `2 tests passed`.

- [ ] **Step 5: Commit**

```bash
git add DiaryCompanionCore
git commit -m "feat: add diary and audit models"
```

## Task 7: Full verification and simulator launch

**Files:**
- No new files

- [ ] **Step 1: Run the complete core test suite**

Run:

```bash
swift test --package-path DiaryCompanionCore
```

Expected: PASS with `12 tests passed`.

- [ ] **Step 2: Build the iOS App**

Run:

```bash
xcodebuild -project DiaryCompanion.xcodeproj \
  -scheme DiaryCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData \
  build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Boot the simulator, install, and launch**

Run:

```bash
xcrun simctl boot 'iPhone 17 Pro' 2>/dev/null || true
open -a Simulator
xcrun simctl install booted \
  DerivedData/Build/Products/Debug-iphonesimulator/DiaryCompanion.app
xcrun simctl launch booted com.liangbowenbill.DiaryCompanion
```

Expected: launch command prints `com.liangbowenbill.DiaryCompanion: <pid>`.

- [ ] **Step 4: Capture a simulator screenshot**

Run:

```bash
mkdir -p artifacts
xcrun simctl io booted screenshot artifacts/diary-companion-foundation.png
```

Expected: screenshot is written to `artifacts/diary-companion-foundation.png`.

- [ ] **Step 5: Check repository status**

Run:

```bash
git status --short
```

Expected: only ignored build output and optional untracked legacy prototype files remain.
