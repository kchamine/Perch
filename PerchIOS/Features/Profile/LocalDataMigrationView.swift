import SwiftUI

struct LocalDataMigrationView: View {
    @EnvironmentObject private var migrationStore: LocalDataMigrationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch migrationStore.sheetMode {
                case .prompt:
                    promptContent
                case .progress:
                    progressContent
                case .none:
                    progressContent
                }
            }
            .padding(20)
            .background(PerchTheme.background.ignoresSafeArea())
            .navigationTitle("Sync local data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(migrationStore.isRunning ? "Syncing" : "Close") {
                        migrationStore.closeProgress()
                        dismiss()
                    }
                    .disabled(migrationStore.isRunning)
                }
            }
        }
    }

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(PerchTheme.primary)

                Text("Move your local Perch into this account")
                    .font(PerchTheme.headline(28))
                    .foregroundStyle(PerchTheme.primary)

                Text("Perch found local-only data on this device. Sync it now to keep it available after sign-in and on other devices.")
                    .font(.subheadline)
                    .foregroundStyle(PerchTheme.textMuted)
                    .lineSpacing(3)
            }

            summaryRows

            Text("Local files stay on this device as a backup after cloud sync succeeds.")
                .font(.footnote)
                .foregroundStyle(PerchTheme.textMuted)

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button {
                    Task { await migrationStore.startMigration() }
                } label: {
                    Label("Sync now", systemImage: "icloud.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PerchTheme.primary)

                Button("Not now") {
                    migrationStore.dismissPrompt()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(PerchTheme.textMuted)
            }
        }
    }

    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(migrationStore.progress.phase)
                    .font(PerchTheme.headline(28))
                    .foregroundStyle(PerchTheme.primary)

                Text(migrationStore.progress.detail)
                    .font(.subheadline)
                    .foregroundStyle(PerchTheme.textMuted)
                    .lineSpacing(3)
            }

            ProgressView(
                value: Double(migrationStore.progress.completed),
                total: Double(max(migrationStore.progress.total, 1))
            )
            .tint(PerchTheme.primary)

            Text("\(migrationStore.progress.completed) of \(migrationStore.progress.total) items")
                .font(PerchTheme.label(10, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(PerchTheme.textMuted)

            if !migrationStore.failures.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Needs retry")
                        .font(.headline)
                        .foregroundStyle(PerchTheme.primary)

                    ForEach(migrationStore.failures) { failure in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(failure.phase)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PerchTheme.primary)
                            Text(failure.message)
                                .font(.footnote)
                                .foregroundStyle(PerchTheme.textMuted)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }

            Spacer(minLength: 0)

            if migrationStore.didFinish {
                VStack(spacing: 10) {
                    if !migrationStore.failures.isEmpty {
                        Button {
                            Task { await migrationStore.startMigration() }
                        } label: {
                            Label("Retry failed items", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PerchTheme.primary)
                    }

                    Button("Done") {
                        migrationStore.closeProgress()
                        dismiss()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var summaryRows: some View {
        VStack(spacing: 10) {
            summaryRow(icon: "mappin.and.ellipse", title: "Spots", value: migrationStore.summary.spotCount)
            summaryRow(icon: "text.bubble", title: "Reviews", value: migrationStore.summary.reviewCount)
            summaryRow(icon: "heart", title: "Favorites", value: migrationStore.summary.favoriteCount)
            if migrationStore.summary.hasProfile {
                HStack {
                    Label("Profile", systemImage: "person.crop.circle")
                    Spacer()
                    Text("1")
                        .font(.headline)
                }
                .font(.subheadline)
                .foregroundStyle(PerchTheme.primary)
            }
        }
        .padding(14)
        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func summaryRow(icon: String, title: String, value: Int) -> some View {
        if value > 0 {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(value)")
                    .font(.headline)
            }
            .font(.subheadline)
            .foregroundStyle(PerchTheme.primary)
        }
    }
}
