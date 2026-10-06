import SwiftUI

extension StockStatus {
    var color: Color {
        switch self {
        case .orderNow: return .statusRed
        case .soon: return .accent
        case .ok: return .statusOk
        case .ordered: return .statusOrdered
        case .missing, .paused: return .subtleText
        }
    }
}

struct StatusTag: View {
    let status: StockStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(status.color.opacity(0.12), in: .rect(cornerRadius: 6))
            .foregroundStyle(status.color)
    }
}

struct RangeBar: View {
    let daysLeft: Int
    let leadDays: Int
    let color: Color
    private let scale = 90.0

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.pillBg)
                Capsule().fill(color)
                    .frame(width: max(8, w * min(1, Double(daysLeft) / scale)))
                let tick = Double(daysLeft - leadDays) / scale
                if tick > 0 && tick < 1 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 3, height: 16)
                        .offset(x: w * tick - 1.5)
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

struct MedicationRow: View {
    let item: MedItem
    let leadDays: Int
    var healthOn: Bool = false

    var body: some View {
        let m = item.med
        let f = item.forecast
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        Text(m.scheduleText)
                        if healthOn && m.healthName != nil {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(Color.accent)
                                .accessibilityLabel("mit Apple Health verknüpft")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Color.subtleText)
                }
                Spacer()
                if let c = f.current {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(c.rounded(.down)))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(f.status.color)
                        Text("Stk.")
                            .font(.caption2)
                            .foregroundStyle(f.status.color.opacity(0.7))
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.pillBorder)
            }

            if let days = f.daysLeft, let until = f.until {
                RangeBar(daysLeft: days, leadDays: leadDays, color: f.status.color)
                HStack(spacing: 8) {
                    StatusTag(status: f.status)
                    Text("reicht bis \(until.shortDay)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                Group {
                    if f.status == .ordered, let d = m.orderedOn {
                        Text("Angefragt am \(d.shortDay)")
                    } else if let o = f.orderBy, let n = f.orderIn {
                        if n <= 0 {
                            Text("Anfordern war fällig am \(o.shortDay)")
                        } else {
                            Text("Rezept anfordern bis \(o.shortDay)")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.subtleText)
            } else {
                StatusTag(status: f.status)
            }
        }
        .card()
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
