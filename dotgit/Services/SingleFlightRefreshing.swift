import Foundation

@MainActor
protocol SingleFlightRefreshing: AnyObject {
    var refreshTask: Task<Void, Never>? { get set }
    func performRefresh() async
}

extension SingleFlightRefreshing {
    func refresh() async {
        refreshTask?.cancel()
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await performRefresh()
        }
        refreshTask = task
        await task.value
    }
}
