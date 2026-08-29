from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

if "import UserNotifications" not in text:
    text = text.replace("import UIKit\n", "import UIKit\nimport UserNotifications\n", 1)

case_marker = '''            default:
                emit(type: "bridgeError", payload: ["message": "Unknown native action: \\(action)"])
'''
case_code = '''            case "scheduleDayNotifications":
                scheduleDayNotifications(
                    dateKey: (body["dateKey"] as? String) ?? "",
                    items: body["items"] as? [[String: Any]] ?? []
                )
            default:
                emit(type: "bridgeError", payload: ["message": "Unknown native action: \\(action)"])
'''
if 'case "scheduleDayNotifications":' not in text:
    if case_marker not in text:
        raise SystemExit("Could not add Live Day notification bridge: switch marker not found")
    text = text.replace(case_marker, case_code, 1)

helper_marker = "        // MARK: - Apple Calendar\n"
helper_code = r'''        // MARK: - Live Day leave reminders

        private func scheduleDayNotifications(dateKey: String, items: [[String: Any]]) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
                guard let self else { return }
                guard granted else {
                    DispatchQueue.main.async {
                        self.emit(type: "dayNotificationsStatus", payload: [
                            "granted": false,
                            "scheduled": 0,
                            "message": error?.localizedDescription ?? "Notification permission is off."
                        ])
                    }
                    return
                }

                let prefix = "liferoute-day-\(dateKey)-"
                center.getPendingNotificationRequests { requests in
                    let oldIDs = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
                    if !oldIDs.isEmpty {
                        center.removePendingNotificationRequests(withIdentifiers: oldIDs)
                    }

                    let formatter = ISO8601DateFormatter()
                    var requestsToAdd: [UNNotificationRequest] = []

                    for item in items.prefix(48) {
                        guard let rawID = item["id"] as? String,
                              let fireISO = item["fireISO"] as? String,
                              let fireDate = formatter.date(from: fireISO),
                              fireDate.timeIntervalSinceNow > 1 else { continue }

                        let content = UNMutableNotificationContent()
                        content.title = (item["title"] as? String) ?? "LifeRoute"
                        content.body = (item["body"] as? String) ?? "Your next departure is coming up."
                        content.sound = .default
                        content.threadIdentifier = "liferoute-live-day"

                        let trigger = UNTimeIntervalNotificationTrigger(
                            timeInterval: max(1, fireDate.timeIntervalSinceNow),
                            repeats: false
                        )
                        requestsToAdd.append(UNNotificationRequest(
                            identifier: prefix + rawID,
                            content: content,
                            trigger: trigger
                        ))
                    }

                    requestsToAdd.forEach { center.add($0) }
                    let scheduledCount = requestsToAdd.count
                    DispatchQueue.main.async {
                        self.emit(type: "dayNotificationsStatus", payload: [
                            "granted": true,
                            "scheduled": scheduledCount
                        ])
                    }
                }
            }
        }

'''
if "private func scheduleDayNotifications(" not in text:
    if helper_marker not in text:
        raise SystemExit("Could not add Live Day notification helper: Apple Calendar marker not found")
    text = text.replace(helper_marker, helper_code + helper_marker, 1)

path.write_text(text)
print("Added native Live Day leave reminders.")
