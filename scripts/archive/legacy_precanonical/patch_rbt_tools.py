from pathlib import Path

path = Path("LifeRoute/LifeRouteWebView.swift")
text = path.read_text()

if "import UserNotifications" not in text:
    text = text.replace("import UIKit\n", "import UIKit\nimport UserNotifications\n", 1)

case_marker = '''            default:
                emit(type: "bridgeError", payload: ["message": "Unknown native action: \\(action)"])
'''
case_code = '''            case "scheduleToolTimer":
                scheduleToolTimer(
                    seconds: (body["seconds"] as? NSNumber)?.doubleValue ?? 0,
                    title: (body["title"] as? String) ?? "Visual timer complete",
                    message: (body["body"] as? String) ?? "Time is up."
                )
            default:
                emit(type: "bridgeError", payload: ["message": "Unknown native action: \\(action)"])
'''
if 'case "scheduleToolTimer":' not in text:
    if case_marker not in text:
        raise SystemExit("Could not add field-tool timer bridge: default switch marker not found")
    text = text.replace(case_marker, case_code, 1)

helper_marker = "        // MARK: - Apple Calendar\n"
helper_code = r'''        // MARK: - Field-tool timer alert

        private func scheduleToolTimer(seconds: Double, title: String, message: String) {
            let center = UNUserNotificationCenter.current()
            let identifier = "liferoute-visual-timer"
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            guard seconds > 0 else {
                emit(type: "toolTimerStatus", payload: ["scheduled": false])
                return
            }

            center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
                guard let self else { return }
                guard granted else {
                    DispatchQueue.main.async {
                        self.emit(type: "toolTimerStatus", payload: [
                            "scheduled": false,
                            "permission": false,
                            "message": error?.localizedDescription ?? "Notification permission is off."
                        ])
                    }
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = message
                content.sound = .default
                content.threadIdentifier = "liferoute-visual-timer"

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, seconds),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: trigger
                )
                center.add(request) { addError in
                    DispatchQueue.main.async {
                        self.emit(type: "toolTimerStatus", payload: [
                            "scheduled": addError == nil,
                            "permission": true
                        ])
                    }
                }
            }
        }

'''
if "private func scheduleToolTimer(" not in text:
    if helper_marker not in text:
        raise SystemExit("Could not add field-tool timer helper: Apple Calendar marker not found")
    text = text.replace(helper_marker, helper_code + helper_marker, 1)

path.write_text(text)
print("Added native visual-timer notification support.")
