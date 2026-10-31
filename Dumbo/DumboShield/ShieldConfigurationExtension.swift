import ManagedSettings
import ManagedSettingsUI
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private func shield() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: .systemBackground,
            icon: UIImage(systemName: "moon.stars.fill"),
            title: .init(text: "A little space to focus", color: .label),
            subtitle: .init(text: "An active Dumbo policy is blocking this app. Open Dumbo to change your list or stop restrictions.", color: .secondaryLabel),
            primaryButtonLabel: .init(text: "Close app", color: .white),
            primaryButtonBackgroundColor: .systemIndigo
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { shield() }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { shield() }
}
