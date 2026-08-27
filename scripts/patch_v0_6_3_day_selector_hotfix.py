#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LifeRoute/V054TodayView.swift"


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    if "v0.6.3 responsive day selector layout" in text:
        return

    old = '''    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("DAY")
            HStack(spacing: 10) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                VStack(spacing: 3) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
                .frame(maxWidth: .infinity)

                DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(palette.accent)

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            if !Calendar.current.isDateInToday(selectedDay) {
                Button {
                    selectedDay = Calendar.current.startOfDay(for: Date())
                    LifeRouteHaptics.selection()
                } label: {
                    Label("Jump to Today", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }
'''

    new = '''    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("DAY")

            // v0.6.3 responsive day selector layout: navigation owns the first row;
            // the compact DatePicker gets its own row so the day title can never collapse vertically.
            HStack(spacing: 12) {
                Button {
                    shiftSelectedDay(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())

                VStack(spacing: 3) {
                    Text(Calendar.current.isDateInToday(selectedDay) ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.headline.weight(.black))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(selectedDay.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                Button {
                    shiftSelectedDay(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }

            HStack(spacing: 10) {
                Label("Choose date", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.textSecondary)
                Spacer(minLength: 8)
                DatePicker("Choose day", selection: $selectedDay, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                    .tint(palette.accent)
            }
            .padding(.horizontal, 4)

            if !Calendar.current.isDateInToday(selectedDay) {
                Button {
                    selectedDay = Calendar.current.startOfDay(for: Date())
                    LifeRouteHaptics.selection()
                } label: {
                    Label("Jump to Today", systemImage: "calendar.badge.clock")
                }
                .buttonStyle(LifeRouteSecondaryButtonStyle())
            }
        }
        .lifeRouteCard()
    }
'''

    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.6.3 day-selector hotfix failed: expected old selector once, found {count}")

    PATH.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("LifeRoute v0.6.3 day-selector layout hotfix applied: responsive title row plus separate compact date row.")


if __name__ == "__main__":
    main()
