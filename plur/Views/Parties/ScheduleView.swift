import SwiftUI
import UIKit

struct ScheduleView: View {
    let party: RaveGroup
    let partyVM: PartyViewModel
    @Bindable var scheduleVM: ScheduleViewModel

    @State private var selectedDayId: UUID?

    private var schedule: EventScheduleRecord? {
        scheduleVM.festivalSchedule(for: party)
    }

    private var days: [ScheduleDayRecord] {
        schedule?.scheduleDays ?? []
    }

    private var selectedDayIdResolved: UUID? {
        selectedDayId ?? days.first?.id
    }

    var body: some View {
        Group {
            if party.raveId == 0 {
                noLineupHint("Link this party to an event (rave ID) to load a lineup.")
            } else if schedule == nil, scheduleVM.scheduleLoadError != nil {
                noLineupHint(scheduleVM.scheduleLoadError ?? "Couldn’t load schedule.")
            } else if let schedule {
                if days.isEmpty {
                    noLineupHint("No days in this schedule yet.")
                } else {
                    scheduleContent(schedule: schedule)
                }
            } else {
                noLineupHint(
                    """
                    This party’s **event ID** is **\(party.raveId)**. There is no `event_schedules` row for that ID yet.

                    The seeded dummy lineup uses **888888**. In Supabase, set `groups.rave_id` to **888888** for this party (Table Editor → `groups`), or create a party linked to that ID when you add matching schedule data.
                    """
                )
            }
        }
        .background(Color.plurVoid)
        .task(id: party.id) {
            await scheduleVM.loadScheduleData(for: party)
        }
    }

    private func scheduleContent(schedule: EventScheduleRecord) -> some View {
        let day = days.first { $0.id == selectedDayIdResolved } ?? days[0]

        return ZStack(alignment: .topLeading) {
            Color.black
            VStack(alignment: .leading, spacing: Spacing.sm) {
                dayPills(schedule: schedule, selectedId: selectedDayIdResolved)

                FestivalScheduleLineupView(
                    schedule: schedule,
                    day: day,
                    party: party,
                    partyVM: partyVM,
                    scheduleVM: scheduleVM
                )
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dayPills(schedule: EventScheduleRecord, selectedId: UUID?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(schedule.scheduleDays ?? []) { day in
                    let isOn = day.id == selectedId
                    Button {
                        selectedDayId = day.id
                    } label: {
                        Text("Day \(day.dayIndex)")
                            .font(.plurMicro())
                            .foregroundStyle(isOn ? Color.plurVoid : Color.plurMuted)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                isOn ? Color.plurGhost : Color.plurSurface2,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func noLineupHint(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Spacer().frame(height: 48)
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.plurFaint)
                Text("No Lineup")
                    .font(.plurH2())
                    .foregroundStyle(Color.plurGhost)
                Text(.init(message))
                    .font(.plurBody())
                    .foregroundStyle(Color.plurMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)
        }
    }
}

// MARK: - Schedule palette (readability on black)

private enum ScheduleColors {
    static let canvas = Color.black
    static let timelineText = Color.white.opacity(0.52)
    static let gridLine = Color.white.opacity(0.15)
    static let columnBg = Color.white.opacity(0.05)
    static let columnBorder = Color.white.opacity(0.2)
    static let headerTitle = Color.white.opacity(0.94)
    static let headerBorder = Color.white.opacity(0.22)
    /// Solid body fill for unselected slots.
    static let slotFill = Color(white: 0.24)
    static let slotTime = Color.white.opacity(0.58)
}

// MARK: - Thin timeline rail (non-interactive)

private struct ScheduleTimelineRail: View {
    let anchor: Date
    let totalHours: Int
    let hourHeight: CGFloat
    let gridTopInset: CGFloat
    let calendar: Calendar
    let height: CGFloat

    private func makeTickFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "ha"
        return f
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: gridTopInset)
            ForEach(0..<totalHours, id: \.self) { hourIndex in
                Text(tickLabel(for: hourIndex))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(ScheduleColors.timelineText)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .frame(height: hourHeight, alignment: .top)
                    .padding(.trailing, 8)
            }
        }
        .frame(height: height, alignment: .top)
        .allowsHitTesting(false)
    }

    private func tickLabel(for hourIndex: Int) -> String {
        guard let t = calendar.date(byAdding: .hour, value: hourIndex, to: anchor) else { return "—" }
        return makeTickFormatter().string(from: t).lowercased()
    }
}

// MARK: - Lineup (header + grid, synced horizontal scroll, fixed timeline rail)

private struct FestivalScheduleLineupView: View {
    private struct GridMetrics {
        let anchor: Date
        let totalHours: Int
        let scrollableHeight: CGFloat
    }

    let schedule: EventScheduleRecord
    let day: ScheduleDayRecord
    let party: RaveGroup
    let partyVM: PartyViewModel
    @Bindable var scheduleVM: ScheduleViewModel

    private let headerHeight: CGFloat = 62
    private let hourHeight: CGFloat = 96
    private let minStageColumnWidth: CGFloat = 104
    private let gridTopInset: CGFloat = 8
    /// Thin left rail; hit-testing off so swipes aren’t eaten.
    private let timelineWidth: CGFloat = 34

    private var stages: [ScheduleStageRecord] {
        schedule.scheduleStages ?? []
    }

    private var daySlots: [ScheduleSlotRecord] {
        (schedule.scheduleSlots ?? []).filter { $0.dayId == day.id }
    }

    private var tz: TimeZone {
        TimeZone(identifier: schedule.timezone) ?? .current
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }

    private func makeSlotTimeFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "h:mm a"
        return f
    }

    /// Start of the hour containing the earliest slot (event timezone), not calendar midnight.
    /// Hour grid derived once from the day’s slots (anchor, span, pixel height).
    private var gridMetrics: GridMetrics? {
        guard let earliest = daySlots.map(\.startAt).min() else { return nil }
        let anchor = calendar.dateInterval(of: .hour, for: earliest)?.start ?? earliest
        guard let lastEnd = daySlots.map(\.endAt).max() else { return nil }
        let secs = lastEnd.timeIntervalSince(anchor)
        let hours = max(1, Int(ceil(secs / 3600)))
        return GridMetrics(
            anchor: anchor,
            totalHours: hours,
            scrollableHeight: CGFloat(hours) * hourHeight + gridTopInset + 8
        )
    }

    private var gridAnchor: Date? { gridMetrics?.anchor }

    private var gridHeight: CGFloat { gridMetrics?.scrollableHeight ?? 200 }

    private var totalHours: Int { gridMetrics?.totalHours ?? 1 }

    var body: some View {
        GeometryReader { geo in
            let stageCount = max(stages.count, 1)
            let availableForStages = max(0, geo.size.width - timelineWidth)
            let stageColumnWidth = resolvedStageColumnWidth(availableForStages: availableForStages, stageCount: stageCount)
            let headerRowHeight = headerHeight + 4
            let viewportGridHeight = max(0, geo.size.height - headerRowHeight)
            let gridHeightResolved = max(gridHeight, viewportGridHeight)
            let stagesWidth = CGFloat(stageCount) * stageColumnWidth

            let corner = AnyView(scheduleCornerHeaderCell)
            let headerRow = AnyView(
                stageHeaderRow(stageColumnWidth: stageColumnWidth)
                    .frame(height: headerHeight)
                    .padding(.bottom, 4)
            )
            let timeline = AnyView(
                Group {
                    if let anchor = gridAnchor {
                        ScheduleTimelineRail(
                            anchor: anchor,
                            totalHours: totalHours,
                            hourHeight: hourHeight,
                            gridTopInset: gridTopInset,
                            calendar: calendar,
                            height: gridHeightResolved
                        )
                        .frame(width: timelineWidth)
                    } else {
                        Color.clear.frame(width: timelineWidth, height: gridHeightResolved)
                    }
                }
            )
            let columns = AnyView(
                HStack(alignment: .top, spacing: 0) {
                    ForEach(stages) { stage in
                        stageColumn(stage: stage, anchor: gridAnchor, width: stageColumnWidth)
                            .frame(width: stageColumnWidth, height: gridHeightResolved)
                    }
                }
            )

            ScheduleLineupScrollHost(
                timelineWidth: timelineWidth,
                headerRowHeight: headerRowHeight,
                gridContentHeight: gridHeightResolved,
                stagesScrollWidth: stagesWidth,
                corner: corner,
                headerRow: headerRow,
                timeline: timeline,
                stageColumns: columns
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ScheduleColors.canvas)
    }

    private var scheduleCornerHeaderCell: some View {
        Text(" ")
            .font(.system(size: 8))
            .frame(width: timelineWidth, height: headerHeight + 4)
            .background(ScheduleColors.canvas)
    }

    private func resolvedStageColumnWidth(availableForStages: CGFloat, stageCount: Int) -> CGFloat {
        let n = max(stageCount, 1)
        let needed = CGFloat(n) * minStageColumnWidth
        if needed > availableForStages {
            return minStageColumnWidth
        }
        return max(minStageColumnWidth, availableForStages / CGFloat(n))
    }

    private func stageHeaderRow(stageColumnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(stages) { stage in
                stageHeaderCell(stage: stage, width: stageColumnWidth)
            }
        }
    }

    private func stageAccent(_ stage: ScheduleStageRecord) -> Color {
        Color(hex: stage.accentColor ?? "7B5EA7")
    }

    private func stageHeaderCell(stage: ScheduleStageRecord, width: CGFloat) -> some View {
        let accent = stageAccent(stage)
        return Text(stage.name.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.95))
            .lineLimit(3)
            .minimumScaleFactor(0.65)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6)
            .frame(width: width, height: headerHeight)
            .background(accent.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(accent)
                    .frame(height: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(accent.opacity(0.6), lineWidth: 1)
            )
    }

    private func stageColumn(stage: ScheduleStageRecord, anchor: Date?, width: CGFloat) -> some View {
        let color = stageAccent(stage)
        let slots = daySlots.filter { $0.stageId == stage.id }
            .sorted { $0.startAt < $1.startAt }

        return ZStack(alignment: .topLeading) {
            ForEach(1..<totalHours, id: \.self) { h in
                Rectangle()
                    .fill(ScheduleColors.gridLine)
                    .frame(height: 1)
                    .offset(y: gridTopInset + CGFloat(h) * hourHeight)
            }

            if let anchor {
                ForEach(slots) { slot in
                    slotBlock(
                        slot: slot,
                        stageColor: color,
                        anchor: anchor,
                        columnWidth: width,
                        sameStageSlots: slots
                    )
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(ScheduleColors.columnBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }

    private func slotBlock(
        slot: ScheduleSlotRecord,
        stageColor: Color,
        anchor: Date,
        columnWidth: CGFloat,
        sameStageSlots: [ScheduleSlotRecord]
    ) -> some View {
        let y = yOffset(start: slot.startAt, anchor: anchor)
        let naturalH = height(start: slot.startAt, end: slot.endAt)
        /// Next set on this stage (by start time). Cap block height so a minimum-height floor cannot paint over the following slot.
        let nextStart = sameStageSlots.lazy.filter { $0.startAt > slot.startAt }.map(\.startAt).min()
        let slotGap: CGFloat = 2
        let maxHToNext = nextStart.map { start in
            max(0, yOffset(start: start, anchor: anchor) - y - slotGap)
        } ?? .greatestFiniteMagnitude
        let minBlockH: CGFloat = 4
        let h = min(max(naturalH, minBlockH), maxHToNext)
        let members = partyVM.members[party.id] ?? []
        let selected = scheduleVM.isSlotSelected(slot.id, groupId: party.id, userId: partyVM.currentUserId)
        let bubbles = scheduleVM.attendeeInitials(for: slot.id, groupId: party.id, members: members)
        let hasAttendees = !bubbles.shown.isEmpty || bubbles.overflow > 0

        let showTime = h >= 44
        /// Taller slots: initials as a bottom row so they never cover the artist name.
        let showAttendeePillRow = hasAttendees && h >= 46 && (columnWidth - 6) >= 40
        /// Very short slots: one subtle line under the title (no overlay).
        let showAttendeeInline = hasAttendees && h < 46 && h >= 26

        return Button {
            Task { await scheduleVM.toggleSlotSelection(slot.id, in: party, userId: partyVM.currentUserId) }
        } label: {
            VStack(alignment: .center, spacing: 3) {
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(selected ? Color.black : stageColor)
                        .frame(width: 2)
                    VStack(alignment: .center, spacing: 2) {
                        Text(slot.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(h < 44 ? 2 : 3)
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        if showTime {
                            Text(slotTimeRange(start: slot.startAt, end: slot.endAt))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ScheduleColors.slotTime)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        if showAttendeeInline {
                            Text(attendeeInlineLabel(shown: bubbles.shown, overflow: bubbles.overflow))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 6)
                    .padding(.vertical, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if showAttendeePillRow {
                    HStack(spacing: 0) {
                        ZStack {
                            // Overlapping avatar circles, right-to-left layering
                            ForEach(Array(bubbles.shown.enumerated().reversed()), id: \.offset) { idx, initials in
                                Text(initials)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(avatarColor(for: initials)))
                                    .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 1.5))
                                    .offset(x: CGFloat(idx) * 11)
                            }
                            if bubbles.overflow > 0 {
                                let overflowOffset = CGFloat(bubbles.shown.count) * 11
                                Text("+\(bubbles.overflow)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Color.white.opacity(0.14)))
                                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.5))
                                    .offset(x: overflowOffset)
                            }
                        }
                        .frame(
                            width: CGFloat(bubbles.shown.count + (bubbles.overflow > 0 ? 1 : 0) - 1) * 11 + 18,
                            height: 18
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
            .frame(width: columnWidth - 8, height: h, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(selected ? stageColor : ScheduleColors.slotFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        selected ? Color.white : stageColor,
                        lineWidth: selected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .offset(y: gridTopInset + y)
    }

    private func attendeeInlineLabel(shown: [String], overflow: Int) -> String {
        var parts = shown
        if overflow > 0 { parts.append("+\(overflow)") }
        return parts.joined(separator: " · ")
    }

    private func yOffset(start: Date, anchor: Date) -> CGFloat {
        CGFloat(start.timeIntervalSince(anchor) / 3600) * hourHeight
    }

    private func height(start: Date, end: Date) -> CGFloat {
        CGFloat(end.timeIntervalSince(start) / 3600) * hourHeight
    }

    private func slotTimeRange(start: Date, end: Date) -> String {
        let formatter = makeSlotTimeFormatter()
        return "\(formatter.string(from: start).uppercased()) – \(formatter.string(from: end).uppercased())"
    }

    private func avatarColor(for initials: String) -> Color {
        let colors: [Color] = [.plurViolet, .plurRose, .plurTeal, .plurAmber]
        let hash = initials.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - UIKit shell: vertical grid + two synced horizontal scroll views

/// Slightly slower deceleration than `.normal` (0.998) so flicks carry a bit farther.
private let scheduleScrollDecelerationRate = UIScrollView.DecelerationRate(rawValue: 0.999)

/// Horizontal stage strip nested inside a vertical `UIScrollView`. UIScrollView’s pan **must** use the scroll
/// view as its delegate (iOS enforces this); we gate pans here instead of assigning an external delegate.
private final class ScheduleNestedBodyHScrollView: UIScrollView {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        let t = panGestureRecognizer.translation(in: self)
        let slack: CGFloat = 2
        if abs(t.y) > abs(t.x) + slack { return false }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

private final class ScheduleScrollSyncCoordinator: NSObject, UIScrollViewDelegate {
    weak var root: ScheduleLineupRootView?
    private var syncing = false

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let root, !syncing else { return }
        let header = root.headerScroll
        let body = root.bodyHScroll
        guard scrollView === header || scrollView === body else { return }
        // Do not clamp x: overscroll (x < 0 or past max) is required for rubber-band bounce.
        let x = scrollView.contentOffset.x
        syncing = true
        defer { syncing = false }
        if scrollView === header {
            body.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        } else {
            header.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }
    }
}

private final class ScheduleLineupRootView: UIView {
    let timelineWidth: CGFloat

    let headerScroll = UIScrollView()
    let bodyHScroll = ScheduleNestedBodyHScrollView()
    let verticalScroll = UIScrollView()

    weak var cornerHost: UIHostingController<AnyView>?
    weak var headerHost: UIHostingController<AnyView>?
    weak var timelineHost: UIHostingController<AnyView>?
    weak var columnsHost: UIHostingController<AnyView>?

    var headerRowHeight: CGFloat = 66
    var gridContentHeight: CGFloat = 400
    var contentStagesWidth: CGFloat = 320

    init(timelineWidth: CGFloat) {
        self.timelineWidth = timelineWidth
        super.init(frame: .zero)
        backgroundColor = .black

        verticalScroll.showsVerticalScrollIndicator = true
        verticalScroll.showsHorizontalScrollIndicator = false
        verticalScroll.alwaysBounceHorizontal = false
        verticalScroll.contentInsetAdjustmentBehavior = .never
        verticalScroll.backgroundColor = .black
        verticalScroll.decelerationRate = scheduleScrollDecelerationRate

        headerScroll.showsVerticalScrollIndicator = false
        headerScroll.showsHorizontalScrollIndicator = true
        headerScroll.alwaysBounceVertical = false
        headerScroll.alwaysBounceHorizontal = true
        headerScroll.bounces = true
        headerScroll.contentInsetAdjustmentBehavior = .never
        headerScroll.backgroundColor = .black
        headerScroll.delaysContentTouches = false
        headerScroll.decelerationRate = scheduleScrollDecelerationRate

        bodyHScroll.showsVerticalScrollIndicator = false
        bodyHScroll.showsHorizontalScrollIndicator = false
        bodyHScroll.alwaysBounceVertical = false
        bodyHScroll.alwaysBounceHorizontal = true
        bodyHScroll.bounces = true
        bodyHScroll.contentInsetAdjustmentBehavior = .never
        bodyHScroll.isDirectionalLockEnabled = true
        bodyHScroll.backgroundColor = .black
        bodyHScroll.delaysContentTouches = false
        bodyHScroll.decelerationRate = scheduleScrollDecelerationRate

        addSubview(verticalScroll)
        addSubview(headerScroll)
        verticalScroll.addSubview(bodyHScroll)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard
            let corner = cornerHost?.view,
            let headerH = headerHost?.view,
            let timeline = timelineHost?.view,
            let columns = columnsHost?.view
        else { return }

        let w = bounds.width
        let h = bounds.height
        let tw = timelineWidth
        let hr = headerRowHeight
        let sw = max(contentStagesWidth, 1)
        let gridH = max(gridContentHeight, 1)

        corner.frame = CGRect(x: 0, y: 0, width: tw, height: hr)
        headerScroll.frame = CGRect(x: tw, y: 0, width: w - tw, height: hr)
        verticalScroll.frame = CGRect(x: 0, y: hr, width: w, height: max(0, h - hr))
        verticalScroll.contentSize = CGSize(width: w, height: gridH)

        // Inset horizontal scroll so column 0 lines up with the header strip (past the timeline).
        bodyHScroll.frame = CGRect(x: tw, y: 0, width: max(0, w - tw), height: gridH)
        timeline.frame = CGRect(x: 0, y: 0, width: tw, height: gridH)
        timeline.isUserInteractionEnabled = false

        headerH.frame = CGRect(x: 0, y: 0, width: sw, height: hr)
        columns.frame = CGRect(x: 0, y: 0, width: sw, height: gridH)

        headerScroll.contentSize = CGSize(width: sw, height: hr)
        bodyHScroll.contentSize = CGSize(width: sw, height: gridH)

        let maxY = max(0, verticalScroll.contentSize.height - verticalScroll.bounds.height)
        var off = verticalScroll.contentOffset
        let y = min(max(0, off.y), maxY)
        if abs(off.y - y) > 0.5 {
            off.y = y
            off.x = 0
            verticalScroll.contentOffset = off
        }
    }
}

private struct ScheduleLineupScrollHost: UIViewRepresentable {
    var timelineWidth: CGFloat
    var headerRowHeight: CGFloat
    var gridContentHeight: CGFloat
    var stagesScrollWidth: CGFloat
    var corner: AnyView
    var headerRow: AnyView
    var timeline: AnyView
    var stageColumns: AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ScheduleLineupRootView {
        let root = ScheduleLineupRootView(timelineWidth: timelineWidth)
        let c = context.coordinator

        let cornerHC = UIHostingController(rootView: corner)
        let headerHC = UIHostingController(rootView: headerRow)
        let timelineHC = UIHostingController(rootView: timeline)
        let columnsHC = UIHostingController(rootView: stageColumns)

        for hc in [cornerHC, headerHC, timelineHC, columnsHC] {
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = true
        }
        cornerHC.view.isUserInteractionEnabled = false
        timelineHC.view.isUserInteractionEnabled = false

        c.cornerHost = cornerHC
        c.headerHost = headerHC
        c.timelineHost = timelineHC
        c.columnsHost = columnsHC

        root.cornerHost = cornerHC
        root.headerHost = headerHC
        root.timelineHost = timelineHC
        root.columnsHost = columnsHC

        root.headerScroll.addSubview(headerHC.view)
        root.bodyHScroll.addSubview(columnsHC.view)
        root.verticalScroll.addSubview(timelineHC.view)
        root.addSubview(cornerHC.view)

        let sync = ScheduleScrollSyncCoordinator()
        sync.root = root
        root.headerScroll.delegate = sync
        root.bodyHScroll.delegate = sync
        c.syncCoordinator = sync

        return root
    }

    func updateUIView(_ root: ScheduleLineupRootView, context: Context) {
        let c = context.coordinator
        c.cornerHost?.rootView = corner
        c.headerHost?.rootView = headerRow
        c.timelineHost?.rootView = timeline
        c.columnsHost?.rootView = stageColumns

        root.headerRowHeight = headerRowHeight
        root.gridContentHeight = gridContentHeight
        root.contentStagesWidth = stagesScrollWidth
        root.setNeedsLayout()
    }

    final class Coordinator {
        var cornerHost: UIHostingController<AnyView>?
        var headerHost: UIHostingController<AnyView>?
        var timelineHost: UIHostingController<AnyView>?
        var columnsHost: UIHostingController<AnyView>?
        var syncCoordinator: ScheduleScrollSyncCoordinator?
    }
}
