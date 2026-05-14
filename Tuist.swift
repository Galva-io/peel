import ProjectDescription

// Tuist is a developer convenience for generating an Xcode project from the
// same source layout SPM uses. `swift build` / `swift test` remain the
// canonical build path (used by CI and for module-level testing); Tuist is
// what gives you a runnable `.app` from inside Xcode with ⌘R.
//
// Run `tuist generate` to produce `Peel.xcodeproj`, then open it.
let tuist = Tuist()
