import Foundation
import Combine

enum LifeRoutePortalCategory: String, CaseIterable, Codable, Identifiable {
    case clinical = "ABA Data & Clinical"
    case hr = "Finance & HR"
    case training = "Training & Credentials"
    case other = "Other Work Portals"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .clinical: return "cross.case.fill"
        case .hr: return "building.2.fill"
        case .training: return "graduationcap.fill"
        case .other: return "link.circle.fill"
        }
    }
}

struct LifeRoutePortalLink: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var subtitle: String
    var urlString: String
    var category: LifeRoutePortalCategory
    var systemImage: String
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        urlString: String,
        category: LifeRoutePortalCategory,
        systemImage: String,
        isCustom: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.urlString = urlString
        self.category = category
        self.systemImage = systemImage
        self.isCustom = isCustom
    }

    var url: URL? {
        URL(string: Self.normalizedURLString(urlString))
    }

    static func normalizedURLString(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        if cleaned.lowercased().hasPrefix("https://") || cleaned.lowercased().hasPrefix("http://") {
            return cleaned
        }
        return "https://\(cleaned)"
    }
}

@MainActor
final class ResourcePortalCore: ObservableObject {
    @Published private(set) var customPortals: [LifeRoutePortalLink] = []

    private static let storageKey = "liferoute.resourcePortals.v1"

    let builtInPortals: [LifeRoutePortalLink] = [
        LifeRoutePortalLink(
            title: "CentralReach",
            subtitle: "ABA clinical, scheduling, and data portal",
            urlString: "https://members.centralreach.com/",
            category: .clinical,
            systemImage: "chart.xyaxis.line"
        ),
        LifeRoutePortalLink(
            title: "Motivity",
            subtitle: "ABA data collection and clinical platform",
            urlString: "https://app.motivity.net/",
            category: .clinical,
            systemImage: "waveform.path.ecg"
        ),
        LifeRoutePortalLink(
            title: "Rethink Behavioral Health",
            subtitle: "Clinical and practice-management portal",
            urlString: "https://webapp.rethinkbehavioralhealth.com/Home/Login",
            category: .clinical,
            systemImage: "brain.head.profile.fill"
        ),
        LifeRoutePortalLink(
            title: "Ensora Data Collection (Catalyst)",
            subtitle: "ABA data collection portal formerly known as Catalyst",
            urlString: "https://secure.datafinch.com/",
            category: .clinical,
            systemImage: "chart.bar.doc.horizontal.fill"
        ),
        LifeRoutePortalLink(
            title: "Theralytics",
            subtitle: "ABA practice and clinical management portal",
            urlString: "https://www.theralytics.net/",
            category: .clinical,
            systemImage: "waveform.path.ecg.rectangle.fill"
        ),
        LifeRoutePortalLink(
            title: "Hi Rasmus",
            subtitle: "ABA data collection and collaboration portal",
            urlString: "https://app.hirasmus.com/",
            category: .clinical,
            systemImage: "person.2.wave.2.fill"
        ),
        LifeRoutePortalLink(
            title: "AlohaABA",
            subtitle: "ABA practice-management portal",
            urlString: "https://alohaaba.com/",
            category: .clinical,
            systemImage: "chart.line.uptrend.xyaxis"
        ),
        LifeRoutePortalLink(
            title: "ADP",
            subtitle: "Payroll, time, benefits, and HR",
            urlString: "https://my.adp.com/",
            category: .hr,
            systemImage: "dollarsign.circle.fill"
        ),
        LifeRoutePortalLink(
            title: "BambooHR",
            subtitle: "Employee and HR portal",
            urlString: "https://app.bamboohr.com/login/",
            category: .hr,
            systemImage: "person.text.rectangle.fill"
        ),
        LifeRoutePortalLink(
            title: "Gusto",
            subtitle: "Payroll and benefits portal",
            urlString: "https://app.gusto.com/login",
            category: .hr,
            systemImage: "banknote.fill"
        ),
        LifeRoutePortalLink(
            title: "Paycom",
            subtitle: "Payroll and workforce management portal",
            urlString: "https://www.paycomonline.net/v4/ee/web.php/app/login",
            category: .hr,
            systemImage: "creditcard.fill"
        ),
        LifeRoutePortalLink(
            title: "Paylocity",
            subtitle: "Payroll and HR portal",
            urlString: "https://access.paylocity.com/",
            category: .hr,
            systemImage: "building.columns.fill"
        ),
        LifeRoutePortalLink(
            title: "UKG",
            subtitle: "Employee login and workforce management",
            urlString: "https://www.ukg.com/solutions/employee-login",
            category: .hr,
            systemImage: "person.crop.rectangle.stack.fill"
        ),
        LifeRoutePortalLink(
            title: "Rippling",
            subtitle: "Payroll, HR, and workforce portal",
            urlString: "https://app.rippling.com/",
            category: .hr,
            systemImage: "person.3.fill"
        ),
        LifeRoutePortalLink(
            title: "Workday",
            subtitle: "HR, payroll, and employee portal",
            urlString: "https://www.workday.com/",
            category: .hr,
            systemImage: "briefcase.fill"
        ),
        LifeRoutePortalLink(
            title: "QuickBooks Workforce",
            subtitle: "Paychecks, time, and workforce portal",
            urlString: "https://workforce.intuit.com/",
            category: .hr,
            systemImage: "clock.badge.checkmark.fill"
        ),
        LifeRoutePortalLink(
            title: "Viventium",
            subtitle: "Payroll and HR portal",
            urlString: "https://www.viventium.com/",
            category: .hr,
            systemImage: "building.2.crop.circle.fill"
        ),
        LifeRoutePortalLink(
            title: "BACB Portal",
            subtitle: "Certification, account, and credential resources",
            urlString: "https://portal.bacb.com/",
            category: .training,
            systemImage: "checkmark.seal.fill"
        ),
        LifeRoutePortalLink(
            title: "Relias",
            subtitle: "Training and continuing education portal",
            urlString: "https://login.reliaslearning.com/",
            category: .training,
            systemImage: "book.closed.fill"
        ),
        LifeRoutePortalLink(
            title: "Therap",
            subtitle: "Human-services documentation portal",
            urlString: "https://secure.therapservices.net/",
            category: .other,
            systemImage: "doc.text.fill"
        ),
        LifeRoutePortalLink(
            title: "HHAeXchange",
            subtitle: "Home-care scheduling and EVV portal",
            urlString: "https://hhaexchange.com/",
            category: .other,
            systemImage: "house.and.flag.fill"
        ),
        LifeRoutePortalLink(
            title: "Sandata",
            subtitle: "EVV and home-care workforce portal",
            urlString: "https://www.sandata.com/",
            category: .other,
            systemImage: "location.fill.viewfinder"
        ),
        LifeRoutePortalLink(
            title: "Microsoft 365",
            subtitle: "Email, files, and Microsoft work apps",
            urlString: "https://www.office.com/",
            category: .other,
            systemImage: "square.grid.2x2.fill"
        ),
        LifeRoutePortalLink(
            title: "Google Workspace",
            subtitle: "Gmail, Drive, Docs, and work apps",
            urlString: "https://workspace.google.com/",
            category: .other,
            systemImage: "square.grid.3x3.fill"
        ),
        LifeRoutePortalLink(
            title: "Slack",
            subtitle: "Workplace messaging and collaboration",
            urlString: "https://app.slack.com/",
            category: .other,
            systemImage: "bubble.left.and.bubble.right.fill"
        ),
        LifeRoutePortalLink(
            title: "Microsoft Teams",
            subtitle: "Workplace chat, meetings, and collaboration",
            urlString: "https://teams.microsoft.com/",
            category: .other,
            systemImage: "person.2.fill"
        )
    ]

    init() {
        restore()
    }

    var allPortals: [LifeRoutePortalLink] {
        builtInPortals + customPortals
    }

    func portals(in category: LifeRoutePortalCategory) -> [LifeRoutePortalLink] {
        allPortals
            .filter { $0.category == category }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func addCustomPortal(title: String, urlString: String, category: LifeRoutePortalCategory) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = LifeRoutePortalLink.normalizedURLString(urlString)
        guard !cleanTitle.isEmpty else {
            throw ResourcePortalError.missingTitle
        }
        guard let url = URL(string: normalizedURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil else {
            throw ResourcePortalError.invalidURL
        }

        customPortals.append(
            LifeRoutePortalLink(
                title: cleanTitle,
                subtitle: "Custom work portal",
                urlString: normalizedURL,
                category: category,
                systemImage: "link.circle.fill",
                isCustom: true
            )
        )
        customPortals.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        persist()
    }

    func removeCustomPortal(id: UUID) {
        customPortals.removeAll { $0.id == id }
        persist()
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([LifeRoutePortalLink].self, from: data) else {
            customPortals = []
            return
        }
        customPortals = decoded.filter(\.isCustom)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customPortals) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

enum ResourcePortalError: LocalizedError {
    case missingTitle
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Enter a portal name."
        case .invalidURL:
            return "Enter a valid website address."
        }
    }
}
