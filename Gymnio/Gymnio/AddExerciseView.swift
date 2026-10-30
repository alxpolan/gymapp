import SwiftUI

struct AddExerciseView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var scheme

    @State private var search = ""
    @State private var customName = ""
    @State private var showDuplicate = false
    @FocusState private var isFocused: Bool

    private var filtered: [CatalogExercise] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return ExerciseCatalog.all }
        return ExerciseCatalog.all.filter { $0.displayName.lowercased().contains(query) }
    }

    private var isCustomValid: Bool { !customName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(store.t("add.title"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))

                TextField(store.t("add.search"), text: $search)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                    .padding(14)
                    .background(
                        scheme == .dark
                            ? Color(hex: "76768080").opacity(0.16)
                            : Color(hex: "78788014").opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(scheme == .dark
                                    ? Color(hex: "76768040").opacity(0.24)
                                    : Color(hex: "78788026").opacity(0.15),
                                    lineWidth: 0.5)
                    )
                    .cornerRadius(12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(filtered) { item in
                            Button { add(item.displayName) } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(LinearGradient(colors: [Color(hex: "5B8DEF"), Color(hex: "A06BFF")],
                                                                        startPoint: .leading, endPoint: .trailing))
                                    Text(item.displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                                    Spacer(minLength: 0)
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 18))
                                        .secondaryText()
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 280)

                Divider()

                Text(store.t("add.custom"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))

                TextField(store.t("add.placeholder"), text: $customName)
                    .font(.system(size: 16))
                    .autocapitalization(.words)
                    .onSubmit { add(customName) }
                    .foregroundColor(scheme == .dark ? Color(hex: "f0f0f0") : Color(hex: "1a1a1a"))
                    .padding(14)
                    .background(
                        scheme == .dark
                            ? Color(hex: "76768080").opacity(0.16)
                            : Color(hex: "78788014").opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(scheme == .dark
                                    ? Color(hex: "76768040").opacity(0.24)
                                    : Color(hex: "78788026").opacity(0.15),
                                    lineWidth: 0.5)
                    )
                    .cornerRadius(12)

                if showDuplicate {
                    Text(store.t("add.duplicate"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "FF3B30"))
                }

                HStack(spacing: 12) {
                    Spacer()
                    GlassBtn(store.t("add.cancel")) {
                        store.showAddExercise = false
                    }
                    GlassBtn(store.t("add.button"), prominent: true) {
                        add(customName)
                    }
                    .opacity(isCustomValid ? 1 : 0.5)
                    .disabled(!isCustomValid)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private func add(_ rawName: String) {
        let trimmed = rawName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if store.exercises.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            showDuplicate = true
            return
        }
        let isFirstExercise = store.entries.isEmpty
        store.addExercise(trimmed, source: "catalog_or_custom")
        store.showAddExercise = false
        // Right after the very first exercise: go straight to logging the first set.
        if isFirstExercise {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                store.quickLogRequest = QuickLogRequest(exercise: trimmed)
            }
        }
    }
}
