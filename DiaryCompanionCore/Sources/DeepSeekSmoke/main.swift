import DiaryCompanionCore
import Foundation

@main
enum DeepSeekSmoke {
    static func main() async {
        do {
            let keychain = KeychainStore(
                service: DeepSeekSmokeConfiguration.keychainService
            )
            guard let apiKey = try keychain.load(
                account: DeepSeekSmokeConfiguration.keychainAccount
            ), !apiKey.isEmpty else {
                writeError(
                    """
                    DeepSeek API Key is missing. Store it securely first:
                    security add-generic-password -U -s \(DeepSeekSmokeConfiguration.keychainService) -a \(DeepSeekSmokeConfiguration.keychainAccount) -w
                    """
                )
                Foundation.exit(2)
            }

            let stream = try await ProviderStreamingClient().events(
                profile: DeepSeekSmokeConfiguration.profile,
                apiKey: apiKey,
                messages: [
                    .init(
                        role: .user,
                        content: "请只回复：DeepSeek 连接成功"
                    ),
                ]
            )
            for try await event in stream {
                switch event {
                case let .textDelta(text):
                    print(text, terminator: "")
                case .reasoningDelta:
                    break
                case .done:
                    print()
                }
            }
        } catch {
            writeError("DeepSeek smoke test failed: \(error)")
            Foundation.exit(1)
        }
    }

    private static func writeError(_ text: String) {
        FileHandle.standardError.write(Data("\(text)\n".utf8))
    }
}
