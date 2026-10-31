import SwiftUI
import PhotosUI

/// Muscle group chips and a photo picker for the user's own exercises.
struct ExerciseMetaFields: View {
    @Binding var muscle: MuscleGroup?
    @Binding var photo: UIImage?
    @EnvironmentObject var store: AppStore
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: store.t("meta.muscle"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MuscleGroup.allCases.filter { $0 != .other }) { group in
                        Button { muscle = (muscle == group) ? nil : group } label: {
                            Text(store.t(group.titleKey))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(muscle == group ? .gymOnAccent : .gymText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(muscle == group ? Color.gymAccent : Color.gymSurfaceRaised))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            SectionLabel(text: store.t("meta.photo"))
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.gymSurfaceRaised)
                    if let photo {
                        Image(uiImage: photo).resizable().scaledToFill()
                    } else {
                        Image(systemName: "photo").foregroundColor(.gymTextSecondary)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text(store.t(photo == nil ? "meta.photo.add" : "meta.photo.change"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.gymAccent)
                }
                if photo != nil {
                    Button(store.t("meta.photo.remove")) { photo = nil }
                        .font(.system(size: 15))
                        .foregroundColor(.gymTextSecondary)
                }
            }
        }
        .onChangeCompat(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = image
                }
            }
        }
    }
}

/// Edit sheet for an existing exercise.
struct ExerciseMetaEditor: View {
    let exercise: String
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var muscle: MuscleGroup?
    @State private var photo: UIImage?
    @State private var type: ExerciseType = .weightReps
    @State private var rest = -1
    @State private var unit = ""
    @State private var loaded = false

    var body: some View {
        ZStack {
            Color.gymBackground.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(exercise).font(.system(size: 22, weight: .heavy)).foregroundColor(.gymText)
                    Spacer()
                    Button(store.t("common.save")) {
                        store.setExerciseMeta(muscle, photo: photo, for: exercise, removePhoto: photo == nil)
                        store.setExerciseType(type == store.defaultExerciseType(for: exercise) ? nil : type,
                                              rest: rest < 0 ? nil : rest, unit: unit.isEmpty ? nil : unit, for: exercise)
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gymAccent)
                }
                ExerciseMetaFields(muscle: $muscle, photo: $photo)

                SectionLabel(text: store.t("meta.type"))
                Picker("", selection: $type) {
                    ForEach(ExerciseType.allCases, id: \.self) { Text(store.t($0.titleKey)).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    SectionLabel(text: store.t("meta.rest"))
                    Spacer()
                    Picker("", selection: $rest) {
                        Text(store.t("meta.rest.default")).tag(-1)
                        Text(store.t("settings.rest.off")).tag(0)
                        ForEach([30, 60, 90, 120, 180, 240], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.gymAccent)
                }
                HStack {
                    SectionLabel(text: store.t("meta.unit"))
                    Spacer()
                    Picker("", selection: $unit) {
                        Text(store.t("meta.rest.default")).tag("")
                        Text("kg").tag("kg")
                        Text("lbs").tag("lbs")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
                Spacer()
            }
            .padding(16)
        }
        .task {
            guard !loaded else { return }
            loaded = true
            if let raw = store.exerciseMeta[exercise]?.muscle { muscle = MuscleGroup(rawValue: raw) }
            photo = store.photo(for: exercise)
            type = store.exerciseType(for: exercise)
            rest = store.exerciseMeta[exercise]?.restSeconds ?? -1
            unit = store.exerciseMeta[exercise]?.unit ?? ""
        }
    }
}
