//
//  AddRoomView.swift
//  BarnClimate
//
//  Screen 8 — Add New: Name, Category, Notes (with validation + save).
//

import SwiftUI

struct AddRoomView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentation

    /// Optional existing room for editing.
    var editingRoom: Room? = nil

    @State private var name: String = ""
    @State private var category: RoomCategory = .livestock
    @State private var notes: String = ""
    @State private var showError = false

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isEditing: Bool { editingRoom != nil }

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        previewCard
                        AppTextField(title: "Name", placeholder: "e.g. North Barn",
                                     text: $name, icon: "house.fill")
                        categorySection
                        AppTextEditor(title: "Notes", text: $notes)

                        if showError {
                            Text("Please enter a name for this zone.")
                                .font(.barn(13, .semibold)).foregroundColor(Brand.critical)
                        }

                        PrimaryButton(title: isEditing ? "Save changes" : "Create zone",
                                      icon: "checkmark") { save() }
                            .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitle(isEditing ? "Edit zone" : "Add new", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentation.wrappedValue.dismiss() }
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .onAppear(perform: load)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var previewCard: some View {
        AppCard {
            HStack(spacing: 14) {
                IconBadge(systemName: category.icon, color: category.tint, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? "New zone" : name)
                        .font(.barn(18, .bold)).foregroundColor(AppColor.text)
                    Text(category.title).font(.barn(13, .medium)).foregroundColor(AppColor.textSecondary)
                    Text(String(format: "Ideal %.0f–%.0f°C • %.0f–%.0f%%",
                                category.idealTemp.lowerBound, category.idealTemp.upperBound,
                                category.idealHumidity.lowerBound, category.idealHumidity.upperBound))
                        .font(.barn(11, .medium)).foregroundColor(AppColor.textMuted)
                }
                Spacer()
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category").font(.barn(13, .semibold)).foregroundColor(AppColor.textSecondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(RoomCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { category = cat }
                        Haptics.tap(settings.hapticsEnabled)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(category == cat ? .white : cat.tint)
                            Text(cat.title).font(.barn(11, .semibold))
                                .foregroundColor(category == cat ? .white : AppColor.text)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(category == cat ? AnyView(LinearGradient(colors: [cat.tint, cat.tint.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyView(AppColor.surface))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(category == cat ? Color.clear : AppColor.separator, lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.95))
                }
            }
        }
    }

    private func load() {
        guard let room = editingRoom else { return }
        name = room.name
        category = room.category
        notes = room.notes
    }

    private func save() {
        guard isValid else {
            withAnimation { showError = true }
            Haptics.warning(settings.hapticsEnabled)
            return
        }
        if var room = editingRoom {
            room.name = name.trimmingCharacters(in: .whitespaces)
            room.category = category
            room.notes = notes
            store.updateRoom(room)
        } else {
            store.addRoom(name: name.trimmingCharacters(in: .whitespaces),
                          category: category, notes: notes)
        }
        Haptics.success(settings.hapticsEnabled)
        presentation.wrappedValue.dismiss()
    }
}
