# Native navigation verification

On 7 November 2026, the Flutter app's real `UITabBarController` navigation was exercised on the booted iPhone 18 Pro simulator running iOS 27.2. Physical touches selected **Prepare → Grow → Support → Prepare → Grow**, and native accessibility snapshots confirmed the selected tab plus the corresponding Flutter page content after every change.

The default accessibility/simulator tap reported success but did not activate these embedded native tab items. AXe physical HID touch events did activate them; this was an automation input difference, with no app callback or native layout changes required. Use an observed tab label with `axe tap --label Grow --tap-style physical --udid <simulator-udid>`, then capture a fresh UI snapshot. The bundled AXe binary may need its adjacent `Frameworks` folder in `DYLD_FRAMEWORK_PATH`.

This verifies native-tab selection and Flutter callback delivery on the declared simulator. It does not certify physical-device touch, VoiceOver traversal or all iOS versions.
