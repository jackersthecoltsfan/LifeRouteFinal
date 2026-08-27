import ActivityKit
import WidgetKit
import SwiftUI

@main
struct LifeRouteLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeRouteLiveDayWidget()
    }
}

struct LifeRouteLiveDayWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeRouteLiveDayAttributes.self) { context in
            LockScreenLiveDayView(context: context)
                .activityBackgroundTint(Color(red: 0.02, green: 0.07, blue: 0.14))
                .activitySystemActionForegroundColor(Color(red: 0.94, green: 0.72, blue: 0.28))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                            .foregroundStyle(.yellow)
                        Text("LifeRoute")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.phaseLabel)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.yellow)
                        Text(context.state.countdownTarget, style: .timer)
                            .font(.headline.weight(.black))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.primaryTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        Label(context.state.routeSummary, systemImage: "car.fill")
                        Spacer()
                        if context.state.returnHomePlanned {
                            Label("Home after", systemImage: "house.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                Text(context.state.countdownTarget, style: .timer)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .frame(maxWidth: 46)
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.yellow)
            }
            .widgetURL(URL(string: "liferoute://today"))
            .keylineTint(.yellow)
        }
    }
}

private struct LockScreenLiveDayView: View {
    let context: ActivityViewContext<LifeRouteLiveDayAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 7) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .foregroundStyle(.yellow)
                    Text("LIFEROUTE · LIVE DAY")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.phaseLabel)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.yellow)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.primaryTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                    Text(context.state.secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(context.state.countdownTarget, style: .timer)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                Label(context.state.routeSummary, systemImage: "car.fill")
                if context.state.returnHomePlanned {
                    Label("Return home", systemImage: "house.fill")
                }
                Spacer()
                Text(context.state.eventStart.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.semibold)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .widgetURL(URL(string: "liferoute://today"))
    }
}
