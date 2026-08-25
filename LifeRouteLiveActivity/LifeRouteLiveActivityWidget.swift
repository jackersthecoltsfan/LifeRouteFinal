import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LifeRouteLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        LifeRouteLiveActivityWidget()
    }
}

struct LifeRouteLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LifeRouteActivityAttributes.self) { context in
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                LifeRouteLockScreenView(context: context, now: timeline.date)
            }
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("LifeRoute", systemImage: "location.fill")
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        if let next = nextCheckpoint(in: context.attributes, at: timeline.date),
                           let leaveAt = next.leaveAt,
                           leaveAt > timeline.date {
                            Text(timerInterval: timeline.date...leaveAt, countsDown: true)
                                .font(.caption.monospacedDigit().bold())
                        } else {
                            Text("Live")
                                .font(.caption.bold())
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TimelineView(.periodic(from: .now, by: 30)) { timeline in
                        let next = nextCheckpoint(in: context.attributes, at: timeline.date)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(next?.title ?? "Day complete")
                                .font(.headline)
                                .lineLimit(1)
                            if let address = next?.address, !address.isEmpty {
                                Text(address)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                Image(systemName: "location.fill")
            } compactTrailing: {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    if let next = nextCheckpoint(in: context.attributes, at: timeline.date),
                       let leaveAt = next.leaveAt,
                       leaveAt > timeline.date {
                        Text(timerInterval: timeline.date...leaveAt, countsDown: true)
                            .font(.caption2.monospacedDigit())
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
            } minimal: {
                Image(systemName: "location.fill")
            }
            .keylineTint(.yellow)
        }
    }
}

private struct LifeRouteLockScreenView: View {
    let context: ActivityViewContext<LifeRouteActivityAttributes>
    let now: Date

    private var checkpoints: [LifeRouteActivityAttributes.Checkpoint] {
        context.attributes.checkpoints.sorted { $0.start < $1.start }
    }

    private var next: LifeRouteActivityAttributes.Checkpoint? {
        checkpoints.first { $0.end > now }
    }

    private var completedCount: Int {
        checkpoints.filter { $0.end <= now }.count
    }

    private var progress: Double {
        guard !checkpoints.isEmpty else { return 1 }
        return min(1, max(0, Double(completedCount) / Double(checkpoints.count)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LifeRoute", systemImage: "location.fill")
                    .font(.caption.bold())
                Spacer()
                Text(context.attributes.dayLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let next {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEXT")
                            .font(.caption2.bold())
                            .foregroundStyle(.yellow)
                        Text(next.title)
                            .font(.title3.bold())
                            .lineLimit(1)
                        if !next.address.isEmpty {
                            Text(next.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if let leaveAt = next.leaveAt, leaveAt > now {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LEAVE IN")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text(timerInterval: now...leaveAt, countsDown: true)
                                .font(.title3.monospacedDigit().bold())
                        }
                    } else if next.start > now {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("STARTS IN")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Text(timerInterval: now...next.start, countsDown: true)
                                .font(.title3.monospacedDigit().bold())
                        }
                    } else {
                        Text("NOW")
                            .font(.headline.bold())
                            .foregroundStyle(.green)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Day complete")
                        .font(.headline.bold())
                }
            }

            ProgressView(value: progress)
            Text("\(min(completedCount, checkpoints.count)) of \(checkpoints.count) stops complete")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private func nextCheckpoint(
    in attributes: LifeRouteActivityAttributes,
    at date: Date
) -> LifeRouteActivityAttributes.Checkpoint? {
    attributes.checkpoints
        .sorted { $0.start < $1.start }
        .first { $0.end > date }
}
