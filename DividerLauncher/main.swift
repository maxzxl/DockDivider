// A Mach-O background executable. Launch Services starts it without activating
// an application; it exits without creating NSApplication, a menu or a window.
import Foundation
exit(EXIT_SUCCESS)
