import Observation
import SwiftData
import SwiftUI

/// Pip's farm, full screen (web/src/ui/play/Garden.tsx): a meadow to scroll
/// and zoom around on, with a level and XP bar, a shop drawer, an order board,
/// and lots of little feedback. Plants grow, buildings take days, animals need
/// a home, and things are ready every day. Time on the farm is limited per day.
struct GardenView: View {
    let profile: ChildProfile

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Tool: Equatable {
        case place(String)
        case move(from: Int?)
        case clear
    }

    enum Drawer { case shop, orders }

    @State private var farm: Farm
    @State private var clock: GardenClock
    /// Growth and the light follow the day and the hour; refreshed when they change.
    @State private var now = Date()
    @State private var tool: Tool?
    @State private var drawer: Drawer?
    @State private var tab: GardenCategory = .plants
    @State private var toast = ""
    @State private var toastTask: Task<Void, Never>?
    @State private var zoom: Int?
    @State private var popups: [FarmPopup] = []
    @State private var popupCounter = 0
    @State private var levelUp: Int?
    /// While drawing a road with a finger, changes collect here and are saved when the finger lifts.
    @State private var draft: Farm?
    @State private var extending = false

    init(profile: ChildProfile) {
        self.profile = profile
        _farm = State(initialValue: profile.farm)
        _clock = State(initialValue: GardenClock(time: profile.gardenTime))
    }

    private var shown: Farm { draft ?? farm }
    private var zoomIndex: Int { zoom ?? (sizeClass == .regular ? 2 : 1) }
    private var drawItem: String? {
        if case .place(let id) = tool, GardenItem.with(id: id)?.connects == true { return id }
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 480
            let layout = FarmLayout(cell: FarmLayout.cellSizes[zoomIndex], rows: shown.rows, compact: compact)
            ZStack {
                world(layout: layout)
                light
                VStack(spacing: 12) {
                    hud(compact: compact)
                    banner
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        zoomButtons
                    }
                    bar
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                if let drawer {
                    FarmDrawer(title: drawer == .shop ? "garden.shop" : "garden.orders", maxHeight: geometry.size.height * 0.78) {
                        withAnimation(.easeOut(duration: 0.2)) { self.drawer = nil }
                    } content: {
                        if drawer == .shop { shopContent } else { ordersContent }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
                }
                if clock.isUp && !extending {
                    SleepingFarm(onBack: { dismiss() }, onMoreTime: { extending = true })
                        .transition(.opacity)
                        .zIndex(40)
                }
                if let levelUp {
                    LevelUpCard(level: levelUp) {
                        withAnimation { self.levelUp = nil }
                    }
                    .transition(.opacity)
                    .zIndex(50)
                }
            }
        }
        .foregroundStyle(FarmColors.ink)
        .background(Color(hex: "#3d8a43").ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .sheet(isPresented: $extending) {
            GrownUpGate {
                MoreGardenTime(name: profile.name, onCancel: { extending = false }) { minutes in
                    grant(minutes)
                    extending = false
                }
            }
        }
        .task { await run() }
        .onAppear { refreshOrders() }
        .onChange(of: farm.garden) { refreshOrders() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveTime() }
        }
        .onDisappear { saveTime() }
    }

    // MARK: World

    private func world(layout: FarmLayout) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            FarmMeadow(
                farm: shown,
                now: now,
                layout: layout,
                showsFreeSquares: tool != nil,
                movingAnchor: movingAnchor,
                popups: popups,
                onTap: tap,
                onDraw: drawItem == nil ? nil : draw,
                onDrawEnd: stopDrawing
            )
        }
        .scrollDisabled(drawItem != nil)
        .defaultScrollAnchor(.topLeading)
        .ignoresSafeArea()
        .simultaneousGesture(MagnifyGesture().onEnded { value in
            if value.magnification > 1.2 { zoomBy(1) } else if value.magnification < 0.83 { zoomBy(-1) }
        })
        .accessibilityIdentifier("garden-scroll")
    }

    /// Light over the farm, by the time of day; night when the farm time is over.
    private var light: some View {
        Group {
            switch clock.isUp ? Daylight.night : Daylight(hour: Calendar.current.component(.hour, from: now)) {
            case .night: Color(red: 20 / 255, green: 30 / 255, blue: 90 / 255).opacity(0.4)
            case .morning: Color(red: 1, green: 190 / 255, blue: 120 / 255).opacity(0.12)
            case .evening:
                LinearGradient(colors: [Color(red: 1, green: 120 / 255, blue: 60 / 255).opacity(0.2), Color(red: 120 / 255, green: 40 / 255, blue: 120 / 255).opacity(0.12)], startPoint: .top, endPoint: .bottom)
            case .day: Color.clear
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 2), value: clock.isUp)
    }

    // MARK: HUD

    private func hud(compact: Bool) -> some View {
        HStack(spacing: 10) {
            CircleIconButton(systemImage: "arrow.left", label: "play.back") { dismiss() }
                .accessibilityIdentifier("garden-back")
            FarmLevelPill(level: shown.level)
                .frame(maxWidth: compact ? 150 : 230)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if clock.time.minutesPerDay > 0 {
                    GardenClockPill(clock: clock, compact: compact)
                }
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { drawer = .orders }
                } label: {
                    Text(verbatim: "🧺 \(shown.goodsCount)").farmPill(compact: compact)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(Text("garden.goodsLabel \(shown.goodsCount)"))
                .accessibilityIdentifier("farm-goods")
                Text(verbatim: "⭐ \(shown.walletStars)")
                    .monospacedDigit()
                    .farmPill(compact: compact)
                    .accessibilityElement()
                    .accessibilityLabel(Text("play.wallet \(shown.walletStars)"))
                    .accessibilityIdentifier("farm-wallet")
            }
        }
    }

    @ViewBuilder private var banner: some View {
        if let text = toast.isEmpty ? bannerText : Optional(toast) {
            HStack(spacing: 12) {
                Text(verbatim: text)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                if tool != nil {
                    Button {
                        tool = nil
                        toast = ""
                    } label: {
                        Text("garden.done")
                            .font(.system(.body, design: .rounded).weight(.heavy))
                            .foregroundStyle(FarmColors.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white, in: .capsule)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("tool-done")
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, tool != nil ? 10 : 18)
            .padding(.vertical, 10)
            .background(FarmColors.ink.opacity(0.9), in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("garden-info")
        }
    }

    private var bannerText: String? {
        switch tool {
        case .place(let id):
            guard let item = GardenItem.with(id: id) else { return nil }
            let itemName = Self.name(item)
            return item.connects ? String(localized: "garden.draw") : String(localized: "garden.placeWhere \(itemName)")
        case .move(let from):
            guard let from, let item = farm.garden[from]?.item else { return String(localized: "garden.movePick") }
            let itemName = Self.name(item)
            return String(localized: "garden.moveWhere \(itemName)")
        case .clear:
            return String(localized: "garden.clearPick")
        case nil:
            return nil
        }
    }

    private var zoomButtons: some View {
        VStack(spacing: 8) {
            RoundTool(symbol: "plus", label: "garden.zoomIn") { zoomBy(1) }
                .disabled(zoomIndex >= FarmLayout.cellSizes.count - 1)
                .accessibilityIdentifier("garden-zoom-in")
            RoundTool(symbol: "minus", label: "garden.zoomOut") { zoomBy(-1) }
                .disabled(zoomIndex <= 0)
                .accessibilityIdentifier("garden-zoom-out")
        }
    }

    private var bar: some View {
        let ready = Farm.readyCells(farm.garden, now: now).count
        let deliverable = farm.orders?.orders.filter { farm.canFulfil($0) }.count ?? 0
        let buttons = HStack(spacing: 8) {
            FarmBarButton(icon: "🛒", title: "garden.shop", style: .shop) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { drawer = .shop }
            }
            .accessibilityIdentifier("farm-shop")
            FarmBarButton(icon: "📋", title: "garden.orders", badge: deliverable) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { drawer = .orders }
            }
            .accessibilityIdentifier("farm-orders")
            if ready > 0 {
                FarmBarButton(icon: "🧺", title: "garden.collectAll", style: .collect, badge: ready, action: collectAll)
                    .accessibilityIdentifier("farm-collect")
                    .transition(.scale.combined(with: .opacity))
            }
            FarmBarButton(icon: "✋", title: "garden.move", style: isMoving ? .active : .plain) {
                tool = isMoving ? nil : .move(from: nil)
                toast = ""
            }
            .accessibilityIdentifier("farm-move")
            FarmBarButton(icon: "🧹", title: "garden.clear", style: tool == .clear ? .active : .plain) {
                tool = tool == .clear ? nil : .clear
                toast = ""
            }
            .accessibilityIdentifier("shop-clear")
        }
        .padding(8)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: ready > 0)

        return ViewThatFits(in: .horizontal) {
            buttons
            ScrollView(.horizontal, showsIndicators: false) { buttons }
        }
        .background(.white.opacity(0.95), in: .rect(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
    }

    private var movingAnchor: Int? {
        if case .move(let from) = tool { return from }
        return nil
    }

    private var isMoving: Bool {
        if case .move = tool { return true }
        return false
    }

    // MARK: Shop

    private var shopContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(GardenCategory.allCases) { category in
                        Button {
                            tab = category
                        } label: {
                            (Text(verbatim: category.icon + " ") + Text(LocalizedStringKey("garden.tab." + category.rawValue)))
                                .font(.system(.body, design: .rounded).weight(.heavy))
                                .foregroundStyle(tab == category ? .white : FarmColors.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(tab == category ? FarmColors.ink : Color(hex: "#efe7d6"), in: .capsule)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityAddTraits(tab == category ? .isSelected : [])
                        .accessibilityIdentifier("garden-tab-\(category.rawValue)")
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 12)], spacing: 12) {
                ForEach(GardenItem.all.filter { $0.category == tab }) { item in
                    shopCard(item)
                }
                if tab == .buildings, let price = farm.nextLandPrice {
                    Button {
                        commit(farm.buyingLand())
                        drawer = nil
                        show(String(localized: "garden.landBought"))
                        sound(.finish)
                    } label: {
                        ShopCardLabel(picture: { Text(verbatim: "🌄").font(.system(size: 44)) }, name: "garden.landCard", price: "\(price) ⭐")
                    }
                    .buttonStyle(ShopCardStyle())
                    .disabled(farm.walletStars < price)
                    .accessibilityIdentifier("garden-land")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func shopCard(_ item: GardenItem) -> some View {
        let locked = farm.level.level < item.level
        let affordable = farm.walletStars >= item.price
        let needsHome = item.needs.map { farm.homeSpace($0, now: now).capacity == 0 } ?? false
        let price = item.price == 0 ? String(localized: "garden.free") : "\(item.price) ⭐"
        return Button {
            pick(item)
        } label: {
            ShopCardLabel(
                picture: {
                    Group {
                        if item.connects {
                            PathArt(id: item.id, links: Farm.Links(e: true, w: true)).frame(width: 56, height: 56)
                        } else if item.shopPicture.hasPrefix("art:") {
                            GardenPicture(picture: item.shopPicture, size: 44).frame(width: 56, height: 56)
                        } else {
                            GardenPicture(picture: item.shopPicture, size: 44)
                        }
                    }
                    .grayscale(locked ? 1 : 0)
                    .opacity(locked ? 0.45 : 1)
                },
                name: LocalizedStringKey(item.nameKey),
                price: locked ? nil : price,
                free: item.price == 0,
                lock: locked ? String(localized: "garden.level \(item.level)") : nil,
                note: !locked && needsHome ? "🏠 " + Self.name(GardenItem.home(for: item.needs!)) : nil
            )
        }
        .buttonStyle(ShopCardStyle(locked: locked))
        .disabled(locked || !affordable)
        .accessibilityLabel(Text(verbatim: [Self.name(item), price, locked ? String(localized: "garden.level \(item.level)") : nil].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityIdentifier("shop-\(item.id)")
    }

    // MARK: Orders

    private var ordersContent: some View {
        let orders = farm.orders?.orders ?? []
        return VStack(alignment: .leading, spacing: 10) {
            DrawerHeading("garden.storage")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Produce.allCases) { kind in
                    Text(verbatim: "\(kind.emoji) \(farm.goods(kind))")
                        .font(.system(.body, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white, in: .capsule)
                        .shadow(color: Color(hex: "#e6dccb"), radius: 0, y: 2)
                        .opacity(farm.goods(kind) > 0 ? 1 : 0.45)
                }
            }
            DrawerHeading("garden.ordersToday")
            if orders.isEmpty {
                Text("garden.noOrders").font(.funkelBody).foregroundStyle(FarmColors.muted)
            }
            ForEach(orders) { order in
                OrderCard(order: order, farm: farm) {
                    commit(farm.fulfilling(order.id))
                    sound(.finish)
                    show(String(localized: "garden.delivered"))
                }
            }
            DrawerHeading("garden.shopFarm")
            Text("garden.sellHint \(Farm.goodsPerStar)").font(.funkelBody).foregroundStyle(FarmColors.muted)
            BigButton(title: "garden.sell \(farm.goodsCount / Farm.goodsPerStar)", systemImage: "basket.fill", color: Color(hex: "#E8A33A")) {
                commit(farm.selling())
                sound(.finish)
                show(String(localized: "garden.sold"))
            }
            .disabled(farm.goodsCount < Farm.goodsPerStar)
            .opacity(farm.goodsCount < Farm.goodsPerStar ? 0.5 : 1)
            .accessibilityIdentifier("farm-sell")
        }
    }

    // MARK: Taps

    private func tap(_ cell: Int) {
        let now = Date()
        let covered = Farm.occupancy(farm.garden)
        guard covered.indices.contains(cell) else { return }
        let anchor = covered[cell]
        let plot = anchor.flatMap { farm.garden[$0] }

        if case .move(let from) = tool {
            guard let from else {
                guard let anchor else { return }
                tool = .move(from: anchor)
                toast = ""
                return
            }
            let next = farm.moving(from: from, to: cell)
            if next == farm {
                sound(.gentle)
                return show(String(localized: "garden.noSpace"))
            }
            haptic()
            tool = .move(from: nil)
            return commit(next, animated: true)
        }
        // Things ready to collect come first: a tap on a hen collects today's egg.
        if let anchor, let plot, Farm.readyProduce(plot, now: now) != nil, tool != .clear {
            haptic()
            return commit(collect(anchor, from: farm, now: now))
        }
        if tool == .clear, let anchor {
            guard farm.canClear(cell, now: now) else {
                sound(.gentle)
                return show(String(localized: "garden.clearBlocked"))
            }
            haptic()
            popup(anchor, "💨", .sparkle)
            return commit(farm.clearing(cell, now: now), animated: true)
        }
        if case .place(let id) = tool, let item = GardenItem.with(id: id), !item.connects, anchor == nil {
            if let problem = farm.placementProblem(at: cell, itemID: id, now: now) {
                sound(.gentle)
                return show(problemText(problem, item: item))
            }
            let next = farm.placing(id, at: cell, now: now)
            let at = next.garden.indices.first { next.garden[$0] != nil && farm.garden[$0] == nil } ?? cell
            haptic()
            popup(at, "✨", .sparkle)
            if item.price > 0 { popup(at, "+\(item.price) XP", .xp, delay: 0.2) }
            if next.walletStars < item.price { tool = nil } // can't afford another
            return commit(next, animated: true)
        }
        if let anchor { show(describe(anchor, now: now)) }
    }

    private func draw(_ cell: Int) {
        guard let id = drawItem else { return }
        let base = draft ?? farm
        let next = base.placing(id, at: cell, now: Date())
        guard next != base else { return }
        draft = next
        haptic()
    }

    private func stopDrawing() {
        if let draft, draft != farm { persist(draft) }
        draft = nil
    }

    private func collect(_ cell: Int, from base: Farm, now: Date, delay: Double = 0) -> Farm {
        let covered = Farm.occupancy(base.garden)
        guard let anchor = covered[cell], let plot = base.garden[anchor], let produce = Farm.readyProduce(plot, now: now) else { return base }
        popup(anchor, "+1 \(produce.emoji)", .goods, delay: delay)
        popup(anchor, "+\(Farm.xpForCollecting) XP", .xp, delay: delay + 0.15)
        return base.collecting(anchor, now: now)
    }

    private func collectAll() {
        let now = Date()
        var next = farm
        for (i, cell) in Farm.readyCells(farm.garden, now: now).enumerated() {
            next = collect(cell, from: next, now: now, delay: Double(min(i, 12)) * 0.09)
        }
        sound(.correct)
        commit(next)
    }

    private func pick(_ item: GardenItem) {
        withAnimation(.easeOut(duration: 0.2)) { drawer = nil }
        tool = .place(item.id)
        if let needs = item.needs, farm.homeSpace(needs, now: now).capacity == 0 {
            let homeName = Self.name(GardenItem.home(for: needs))
            show(String(localized: "garden.needs \(homeName)"))
        } else {
            toast = ""
        }
    }

    private func describe(_ anchor: Int, now: Date) -> String {
        guard let plot = farm.garden[anchor], let item = plot.item else { return "" }
        let itemName = Self.name(item)
        let days = Farm.daysUntilNextStage(plot, now: now)
        if Farm.isUnderConstruction(plot, now: now) {
            return "\(itemName): " + String(localized: "garden.builds \(days ?? 1)")
        }
        if let days { return "\(itemName): " + String(localized: "garden.grows \(days)") }
        if let houses = item.houses {
            let space = farm.homeSpace(houses.group, now: now)
            return "\(itemName): " + String(localized: "garden.places \(max(0, space.capacity - space.used))")
        }
        if item.produce != nil { return "\(itemName): " + String(localized: "garden.tomorrow") }
        return itemName
    }

    private func problemText(_ problem: PlacementProblem, item: GardenItem) -> String {
        let homeName = item.needs.map { Self.name(GardenItem.home(for: $0)) } ?? ""
        switch problem {
        case .home: return String(localized: "garden.needs \(homeName)")
        case .full: return String(localized: "garden.full \(homeName)")
        case .space: return String(localized: "garden.noSpace")
        case .level: return String(localized: "garden.level \(item.level)")
        case .stars: return String(localized: "garden.noStars")
        }
    }

    static func name(_ item: GardenItem) -> String {
        NSLocalizedString(item.nameKey, comment: "")
    }

    // MARK: Saving

    /// Saves a change; celebrates a new farm level.
    private func commit(_ next: Farm, animated: Bool = false) {
        guard next != farm else { return }
        let before = farm.level.level, after = next.level.level
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { persist(next) }
        } else {
            persist(next)
        }
        if after > before {
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { levelUp = after }
                sound(.finish)
            }
        }
    }

    /// Saves the farm, together with the garden time counted so far.
    private func persist(_ next: Farm) {
        farm = next
        profile.setFarm(next)
        if clock.pending > 0 {
            clock.time = clock.time.adding(seconds: clock.pending, now: Date())
            clock.pending = 0
            profile.setGardenTime(clock.time)
        }
        try? modelContext.save()
    }

    private func saveTime() {
        guard clock.pending > 0 else { return }
        persist(farm)
    }

    /// Today's orders are made when the farm opens (and once there is something to order).
    private func refreshOrders() {
        let withOrders = farm.withTodaysOrders(now: Date())
        if withOrders != farm { persist(withOrders) }
    }

    private func grant(_ minutes: Int) {
        clock.time = clock.time.adding(seconds: clock.pending, now: Date()).granting(minutes: minutes, now: Date())
        clock.pending = 0
        profile.setGardenTime(clock.time)
        try? modelContext.save()
        clock.refresh(now: Date())
        toast = ""
    }

    // MARK: Time

    /// Garden time: counted every second while the farm is on screen, saved with every change (and every 15 s).
    private func run() async {
        clock.refresh(now: Date())
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            tick()
        }
    }

    private func tick() {
        let date = Date()
        let calendar = Calendar.current
        if FarmDay.key(date) != FarmDay.key(now) || calendar.component(.hour, from: date) != calendar.component(.hour, from: now) {
            now = date
        }
        defer { clock.refresh(now: date) }
        guard scenePhase == .active, let left = clock.time.secondsLeft(now: date), left - clock.pending > 0 else { return }
        clock.pending += 1
        let remaining = left - clock.pending
        if remaining == 120 { show(String(localized: "garden.timeWarning")) }
        if remaining <= 0 {
            persist(farm)
            sound(.finish)
        } else if clock.pending >= 15 {
            persist(farm)
        }
    }

    // MARK: Feedback

    private func show(_ text: String) {
        withAnimation(.easeOut(duration: 0.25)) { toast = text }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { toast = "" }
        }
    }

    private func popup(_ cell: Int, _ text: String, _ kind: FarmPopup.Kind, delay: Double = 0) {
        popupCounter += 1
        let popup = FarmPopup(id: popupCounter, cell: cell, text: text, kind: kind)
        Task {
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            popups.append(popup)
            try? await Task.sleep(for: .seconds(1.3))
            popups.removeAll { $0.id == popup.id }
        }
    }

    private func zoomBy(_ step: Int) {
        let next = min(max(zoomIndex + step, 0), FarmLayout.cellSizes.count - 1)
        guard next != zoomIndex else { return }
        withAnimation(.easeInOut(duration: 0.25)) { zoom = next }
    }

    private func sound(_ effect: SoundService.Effect) {
        if profile.soundEnabled { environment.sound.play(effect) }
    }

    private func haptic() {
        if profile.hapticsEnabled { Haptics.tap() }
    }
}

/// Garden time while the farm is open. Only the clock reads the seconds, so
/// the meadow isn't redrawn every second.
@Observable
final class GardenClock {
    var time: GardenTime
    /// Seconds counted since the last save.
    var pending = 0
    /// Today's garden time is used up.
    private(set) var isUp = false

    init(time: GardenTime) {
        self.time = time
        isUp = time.secondsLeft(now: Date()) == 0
    }

    func secondsLeft(now: Date) -> Int? {
        time.secondsLeft(now: now).map { max(0, $0 - pending) }
    }

    func refresh(now: Date) {
        let up = secondsLeft(now: now) == 0
        if up != isUp { isUp = up }
    }
}

private enum Daylight {
    case morning, day, evening, night

    init(hour: Int) {
        if hour >= 20 || hour < 6 { self = .night } else if hour < 9 { self = .morning } else if hour >= 17 { self = .evening } else { self = .day }
    }
}
