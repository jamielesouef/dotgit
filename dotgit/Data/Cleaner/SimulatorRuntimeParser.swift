import Foundation

enum SimulatorRuntimeParser {
    private struct Payload: Decodable {
        let name: String?
        let version: String?
        let build: String?
        let sizeBytes: Int64?
        let deletable: Bool?
        let path: String?
        let runtimeIdentifier: String?
    }

    static func parse(_ json: String) -> [SimulatorRuntime] {
        guard let data = json.data(using: .utf8) else {
            return []
        }
        guard let payloads = try? JSONDecoder().decode([String: Payload].self, from: data) else {
            return []
        }

        return payloads
            .map { identifier, payload in
                SimulatorRuntime(
                    identifier: identifier,
                    name: payload.name ?? payload.runtimeIdentifier ?? identifier,
                    version: payload.version ?? "",
                    build: payload.build ?? "",
                    sizeBytes: payload.sizeBytes ?? 0,
                    isDeletable: payload.deletable ?? false,
                    path: payload.path
                )
            }
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }
}
