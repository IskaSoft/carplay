import CarPlay
import UIKit

// ─── Shared data model ─────────────────────────────────────────────────────

struct DrivingData {
    var currentSpeedDisplay: String = "0"
    var averageSpeedDisplay: String = "0"
    var speedUnit: String = "km/h"
    var distanceDisplay: String = "0 km"
    var durationDisplay: String = "00:00"
    var tripStatus: String = "idle"
    var currentSpeedKmh: Double = 0.0
    var averageSpeedKmh: Double = 0.0
}

// ─── Singleton controller ─────────────────────────────────────────────────

/**
 * Central controller that:
 *  1. Receives DrivingData from AppDelegate (Flutter channel)
 *  2. Pushes refreshed CPInformationTemplate to the active CarPlay interface
 *
 * Architecture note:
 *  Flutter owns all data; Swift only renders it.
 *  No GPS or calculation logic lives in Swift.
 */
final class CarPlayController {

    static let shared = CarPlayController()
    private init() {}

    private var interfaceController: CPInterfaceController?
    private var dashboardController: CPDashboardController?
    private var currentData = DrivingData()

    // ─── Called by AppDelegate ────────────────────────────────────────────

    func update(with data: DrivingData) {
        currentData = data
        DispatchQueue.main.async { [weak self] in
            self?.refreshTemplate()
        }
    }

    // ─── Called by SceneDelegate ──────────────────────────────────────────

    func connect(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        pushDashboardTemplate()
    }

    func disconnect() {
        interfaceController = nil
    }

    func connectDashboard(_ controller: CPDashboardController) {
        dashboardController = controller
    }

    // ─── Template management ──────────────────────────────────────────────

    private func pushDashboardTemplate() {
        let template = buildTemplate()
        interfaceController?.setRootTemplate(template, animated: false) { _, _ in }
    }

    private func refreshTemplate() {
        guard let controller = interfaceController else { return }
        let template = buildTemplate()
        // If a template is already shown, update it via setRootTemplate
        controller.setRootTemplate(template, animated: false) { _, _ in }
    }

    /**
     * Builds a CPInformationTemplate — approved for all CarPlay app categories.
     *
     * Speed value is displayed as the title (maximum prominence).
     * Secondary stats fill the information rows below.
     */
    private func buildTemplate() -> CPInformationTemplate {
        let data = currentData
        let isActive = data.tripStatus == "driving" || data.tripStatus == "paused"

        let title = isActive
            ? "\(data.currentSpeedDisplay) \(data.speedUnit)"
            : "Average"

        var items: [CPInformationItem] = []

        if isActive {
            items.append(CPInformationItem(
                title: "Average",
                detail: "\(data.averageSpeedDisplay) \(data.speedUnit)"
            ))
            items.append(CPInformationItem(
                title: "Distance",
                detail: data.distanceDisplay
            ))
            items.append(CPInformationItem(
                title: "Duration",
                detail: data.durationDisplay
            ))
            if data.tripStatus == "paused" {
                items.append(CPInformationItem(title: "Status", detail: "Paused"))
            }
        } else {
            items.append(CPInformationItem(
                title: "Status",
                detail: "Open CarPlay on your iPhone to start"
            ))
        }

        let template = CPInformationTemplate(
            title: title,
            layout: .leading,
            items: items,
            actions: []  // No driver-distraction actions needed
        )

        return template
    }
}

// ─── CarPlay Scene Delegate ───────────────────────────────────────────────

/**
 * Registered in Info.plist under CPTemplateApplicationSceneSessionRoleApplication.
 * CarPlay calls this independently of the phone UI scene.
 */
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        CarPlayController.shared.connect(interfaceController: interfaceController)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        CarPlayController.shared.disconnect()
    }
}

// ─── CarPlay Dashboard Scene Delegate ────────────────────────────────────

/**
 * Optional: provides a compact view on the CarPlay Dashboard.
 */
class CarPlayDashboardSceneDelegate: UIResponder, CPTemplateApplicationDashboardSceneDelegate {

    func templateApplicationDashboardScene(
        _ dashboardScene: CPTemplateApplicationDashboardScene,
        didConnect dashboardController: CPDashboardController,
        to window: UIWindow
    ) {
        CarPlayController.shared.connectDashboard(dashboardController)
    }

    func templateApplicationDashboardScene(
        _ dashboardScene: CPTemplateApplicationDashboardScene,
        didDisconnectDashboardController dashboardController: CPDashboardController
    ) {}
}
