import AppKit

// No @main here: an executable target with a main.swift wants the top-level
// form, and it keeps the launch sequence readable.
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
// .accessory keeps the app out of the Dock and the app switcher; the Info.plist
// LSUIElement flag does the same for a bundled build, and both is fine.
application.setActivationPolicy(.accessory)
application.run()
