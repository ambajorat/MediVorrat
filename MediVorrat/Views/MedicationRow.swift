import SwiftUI

extension StockStatus {
    var color: Color {
        switch self {
        case .orderNow: return .red
        case .soon: return .orange
        case .ok: return .green
        case .ordered: return .blue
        case .missing, .paused: return .secondary
        }
    }
}

struct StatusTag: View {
    let status: StockStatus
    var body: some View {
        Text(status.label)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(status.color.opacity(0.18), in: Capsule())
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
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule().fill(color)
                    .frame(width: max(8, w * min(1, Double(daysLeft) / scale)))
                let tick = Double(daysLeft - leadDays) / scale
                if tick > 0 && tick < 1 {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 3, height: 18)
                        .offset(x: w * tick - 1.5)
                }
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

struct MedicationRow: View {
    let item: MedItem
    let leadDays: Int

    var body: some View {
        let m = item.med
        let f = item.forecast
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.displayName).font(.headline)
                    HStack(spacing: 4) {
                        Text("\(m.dosesPerDay.pieces) pro Tag")
                        if m.healthName != nil {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                                .accessibilityLabel("mit Apple Health verknüpft")
                        }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let c = f.current {
                    Text("\(Int(c.rounded(.down)))")
                        .font(.title2.bold().monospacedDigit())
                    + Text(" Stk.").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let days = f.daysLeft, let until = f.until {
                RangeBar(daysLeft: days, leadDays: leadDays, color: f.status.color)
                HStack(spacing: 6) {
                    StatusTag(status: f.status)
                    Text("reicht bis \(until.shortDay)")
                        .font(.subheadline)
                }
                if f.status == .ordered, let d = m.orderedOn {
                    Text("Angefragt am \(d.shortDay)").font(.footnote).foregroundStyle(.secondary)
                } else if let o = f.orderBy, let n = f.orderIn {
                    Text(n <= 0 ? "Anfordern war fällig am \(o.shortDay)" : "Rezept anfordern bis \(o.shortDay)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                StatusTag(status: f.status)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
