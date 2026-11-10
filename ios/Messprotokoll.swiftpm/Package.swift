// swift-tools-version: 5.8

// App-Paket für Xcode / Swift Playgrounds (keine externen Abhängigkeiten).
// Öffnen: Doppelklick auf den Ordner „Messprotokoll.swiftpm“ im Finder.

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "Messprotokoll",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "Messprotokoll",
            targets: ["AppModule"],
            // Falls Xcode meldet, dass die ID schon vergeben ist: z. B. „de.deinname.messprotokoll“ eintragen.
            bundleIdentifier: "de.jufo.calera.messprotokoll",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .clock),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ]
)
