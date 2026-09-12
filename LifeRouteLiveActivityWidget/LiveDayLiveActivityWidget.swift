import ActivityKit
import WidgetKit
import SwiftUI

// v0.7.0 official LifeRoute widget micro mark: simplified LR/pin identity for tiny system surfaces.
private struct LifeRouteWidgetBrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(red: 0.01, green: 0.04, blue: 0.10))
            Text("LR")
                .font(.system(size: 8.2, weight: .black, design: .serif))
                .tracking(-0.8)
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.34))
            Circle()
                .fill(Color(red: 1.0, green: 0.88, blue: 0.46))
                .frame(width: 2.8, height: 2.8)
                .offset(y: -4.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("LifeRoute")
    }
}

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
                        LifeRouteWidgetBrandMark()
                            .frame(width: 20, height: 20)
                        Text("LifeRoute")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        LiveDayPhaseLabel(context: context)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.yellow)
                        LiveDayCountdown(context: context)
                            .font(.headline.weight(.black))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.isStale ? "Open LifeRoute to update" : context.state.primaryTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale {
                        Text("Schedule status needs an update. Open LifeRoute to refresh.")
                            .font(.caption)
                    } else {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 10) {
                            Label(context.state.routeSummary, systemImage: "car.fill")
                            Spacer()
                            if context.state.returnHomePlanned {
                                Label("Home after", systemImage: "house.fill")
                            }
                        }
                        if let stops = context.state.plannedStopSummary {
                            Label(stops, systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                LifeRouteWidgetBrandMark()
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                LiveDayCountdown(context: context)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .frame(maxWidth: 46)
            } minimal: {
                if context.isStale {
                    Image(systemName: "clock.badge.exclamationmark")
                        .accessibilityLabel("Live Day needs an update")
                } else {
                    LifeRouteWidgetBrandMark().frame(width: 18, height: 18)
                }
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
                    LifeRouteWidgetBrandMark()
                        .frame(width: 20, height: 20)
                    Text("LIFEROUTE · LIVE DAY")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                LiveDayPhaseLabel(context: context)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.yellow)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.isStale ? "Open LifeRoute to update" : context.state.primaryTitle)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                    Text(context.isStale ? "Schedule status needs an update." : context.state.secondaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                LiveDayCountdown(context: context)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }

            if !context.isStale {
                HStack(spacing: 12) {
                    Label(context.state.routeSummary, systemImage: "car.fill")
                    if context.state.returnHomePlanned {
                        Label("Return home", systemImage: "house.fill")
                    }
                    Spacer()
                    if let eventStart = context.state.eventStart {
                        Text(eventStart.formatted(date: .omitted, time: .shortened))
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if let stops = context.state.plannedStopSummary {
                    Label(stops, systemImage: "mappin.and.ellipse")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .widgetURL(URL(string: "liferoute://today"))
    }
}

/// A bounded system countdown never changes into elapsed time after its target.
private struct LiveDayCountdown: View {
    let context: ActivityViewContext<LifeRouteLiveDayAttributes>

    var body: some View {
        if context.isStale {
            Image(systemName: "clock.badge.exclamationmark")
                .accessibilityLabel("Live Day needs an update")
        } else if let target = context.state.countdownTarget {
            Text(timerInterval: min(context.attributes.launchedAt, target)...target, countsDown: true)
        } else {
            Text(context.state.phaseLabel == "DAY COMPLETE" ? "Done" : "—")
        }
    }
}

private struct LiveDayPhaseLabel: View {
    let context: ActivityViewContext<LifeRouteLiveDayAttributes>

    var body: some View {
        Text(context.isStale ? "UPDATE NEEDED" : context.state.phaseLabel
            .replacingOccurrences(of: " AT", with: " IN")
            .replacingOccurrences(of: "UNTIL", with: "REMAINING"))
    }
}
