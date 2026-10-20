import PhotosUI
import PlayerzAPI
import SwiftUI
import UniformTypeIdentifiers

/// «Сертификат»: what was uploaded, and a new one from Files, Photos or the
/// camera. Only playerz's own team ever sees it; no route gives it back to
/// the coach, a club or a player. Locked while the profile is reviewed and
/// once it is approved: the approval was given on that document.
struct CoachCertificateSection: View {
    let profile: Components.Schemas.MyCoachProfile
    let model: CoachProfileModel
    @Bindable var session: SessionModel

    @State private var importing = false
    @State private var photo: PhotosPickerItem?
    @State private var shooting = false

    private static let types: [UTType] = [.pdf, .jpeg, .png, .webP]

    var body: some View {
        Section {
            Text(uploaded).foregroundStyle(profile.certificate == nil ? .secondary : .primary)
            if profile.canEdit.certificate {
                // Each presenter on its own row: a Section's modifiers apply to every row.
                Button(String(localized: "coachProfile.certificate.fromFiles"), systemImage: "doc", action: chooseFile)
                    .disabled(model.busy)
                    .fileImporter(isPresented: $importing, allowedContentTypes: Self.types, onCompletion: imported)
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(String(localized: "coachProfile.certificate.fromPhotos"), systemImage: "photo")
                }
                .disabled(model.busy)
                .onChange(of: photo) { _, item in
                    guard let item else { return }
                    Task { await upload(item) }
                }
                if CameraPicker.isAvailable {
                    Button(String(localized: "coachProfile.certificate.fromCamera"), systemImage: "camera", action: shoot)
                        .disabled(model.busy)
                        .sheet(isPresented: $shooting) {
                            CameraPicker(taken: taken).ignoresSafeArea()
                        }
                }
                if profile.certificate != nil {
                    Button(String(localized: "coachProfile.certificate.remove"), role: .destructive, action: remove)
                        .disabled(model.busy)
                }
            }
        } header: {
            Text(String(localized: "coachProfile.certificate.title"))
        } footer: {
            Text(footer)
        }
    }

    private var uploaded: String {
        guard let file = profile.certificate else { return String(localized: "coachProfile.certificate.none") }
        let size = file.byteSize.formatted(.byteCount(style: .file))
        let date = file.uploadedAt.formatted(date: .abbreviated, time: .omitted)
        return String(localized: "coachProfile.certificate.uploaded \(file.fileName) \(size) \(date)")
    }

    private var footer: String {
        var lines = [String(localized: "coachProfile.certificate.hint \(5)")]
        switch profile.state {
        case .SUBMITTED: lines.append(String(localized: "coachProfile.certificate.lockedSubmitted"))
        case .APPROVED: lines.append(String(localized: "coachProfile.certificate.lockedApproved"))
        case .DRAFT, .DECLINED where profile.certificate != nil:
            lines.append(String(localized: "coachProfile.certificate.keptDays \(CoachProfileModel.keptDays)"))
        default: break
        }
        return lines.joined(separator: " ")
    }

    private func chooseFile() {
        importing = true
    }

    private func shoot() {
        shooting = true
    }

    private func remove() {
        Task { await model.removeCertificate(session) }
    }

    private func imported(_ result: Result<URL, Error>) {
        guard case let .success(url) = result else { return }
        Task {
            let reading = url.startAccessingSecurityScopedResource()
            defer { if reading { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            await model.upload(data, fileName: url.lastPathComponent, session)
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { photo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        await model.upload(data, fileName: "certificate.jpg", session)
    }

    private func taken(_ data: Data?) {
        shooting = false
        guard let data else { return }
        Task { await model.upload(data, fileName: "certificate.jpg", session) }
    }
}
