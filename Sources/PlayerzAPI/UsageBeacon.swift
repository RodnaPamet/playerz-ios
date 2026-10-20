import Foundation

/// The venue page's two beacon events (`POST /venues/{id}/usage-events`,
/// RodnaPamet/projectZ#371; playerz-ios#17), for the club's usage counts.
///
/// The app books straight from the slot, with no confirm sheet, so one tap on
/// «Резервирай» is both: the web's funnel (a slot picked, the sheet opened, a
/// booking made) stays comparable. A venue looked at is counted by the server
/// when the app reads it.
public enum UsageBeacon: String, Sendable, CaseIterable {
    case slotPicked = "SLOT_PICKED"
    case sheetOpened = "SHEET_OPENED"
}
