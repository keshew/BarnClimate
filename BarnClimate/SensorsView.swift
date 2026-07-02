//
//  SensorsView.swift
//  BarnClimate
//
//  Screen 7 — Projects / Groups: list of monitored zones with filtering.
//

import SwiftUI

struct SensorsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings

    @State private var filter: RoomCategory? = nil
    @State private var showAddRoom = false

    private var filteredRooms: [Room] {
        guard let filter = filter else { return store.rooms }
        return store.rooms.filter { $0.category == filter }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        summaryStrip
                        filterChips
                        if filteredRooms.isEmpty {
                            EmptyStateView(icon: "gauge",
                                           title: "No zones here",
                                           message: "Add a new zone to start monitoring its climate.",
                                           actionTitle: "Add zone") { showAddRoom = true }
                        } else {
                            ForEach(filteredRooms) { room in
                                NavigationLink(destination: RoomDetailView(roomID: room.id)) {
                                    RoomCardView(room: room)
                                }
                                .buttonStyle(ScaleButtonStyle(scale: 0.98))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 110)
                }
            }
            .navigationBarTitle("Sensors", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddRoom = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(Brand.greenDeep)
                    }
                }
            }
            .sheet(isPresented: $showAddRoom) { AddRoomView() }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summaryTile("\(store.statusCount(.good))", "Good", Brand.good)
            summaryTile("\(store.statusCount(.warning))", "Warning", Brand.warning)
            summaryTile("\(store.statusCount(.critical))", "Critical", Brand.critical)
        }
    }

    private func summaryTile(_ value: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.barn(22, .bold)).foregroundColor(tint)
            Text(title).font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppColor.separator, lineWidth: 1))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                SelectableChip(title: "All", icon: "square.grid.2x2.fill",
                               isSelected: filter == nil, tint: Brand.greenDeep) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { filter = nil }
                }
                ForEach(RoomCategory.allCases) { cat in
                    SelectableChip(title: cat.title, icon: cat.icon,
                                   isSelected: filter == cat, tint: cat.tint) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { filter = cat }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Room card

struct RoomCardView: View {
    @EnvironmentObject var settings: AppSettings
    let room: Room

    var body: some View {
        AppCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    IconBadge(systemName: room.category.icon, color: room.category.tint, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(room.name).font(.barn(17, .bold)).foregroundColor(AppColor.text)
                        Text(room.category.title).font(.barn(12, .medium)).foregroundColor(AppColor.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: room.status, compact: false)
                }
                HStack(spacing: 10) {
                    miniReading("thermometer", Brand.critical, settings.temperatureText(room.temperature, decimals: 0))
                    miniReading("drop.fill", Brand.blue, String(format: "%.0f%%", room.humidity))
                    miniReading("wind", Brand.cyan, String(format: "%.0f%%", room.ventilation))
                    Spacer()
                    Sparkline(values: room.history.map { $0.temperature }, color: room.category.tint)
                        .frame(width: 70, height: 34)
                }
            }
        }
    }

    private func miniReading(_ icon: String, _ tint: Color, _ value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundColor(tint)
            Text(value).font(.barn(13, .bold)).foregroundColor(AppColor.text)
        }
    }
}
