import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Binding var isShowingSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AuthField?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                formCard
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PerchTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Button {
                isShowingSignUp = false
            } label: {
                Text("Already have an account? Sign in")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PerchTheme.primary)
            .background(PerchTheme.surface)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create your Perch account")
                .font(PerchTheme.headline(36))
                .foregroundStyle(PerchTheme.primary)
            Text("Use email and password for the first backend-backed Perch identity.")
                .font(.headline)
                .foregroundStyle(PerchTheme.textMuted)
                .lineSpacing(3)
        }
        .padding(.top, 40)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign up")
                .font(PerchTheme.headline(28))
                .foregroundStyle(PerchTheme.primary)

            authTextField("Email", text: $email, keyboard: .emailAddress)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .padding(14)
                .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            SecureField("Confirm password", text: $confirmPassword)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .padding(14)
                .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }

            Button {
                submit()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSubmitting ? "Creating account..." : "Create account")
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(PerchTheme.primary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .padding(20)
        .perchGlassCard()
    }

    private func submit() {
        guard validateFields() else { return }
        isSubmitting = true
        errorMessage = nil
        focusedField = nil

        Task {
            do {
                try await authStore.signUp(email: email, password: password)
            } catch {
                errorMessage = PerchAuthError.map(error).localizedDescription
            }
            isSubmitting = false
        }
    }

    private func validateFields() -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            focusedField = .email
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Use at least 6 characters for your password."
            focusedField = .password
            return false
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            focusedField = .confirmPassword
            return false
        }
        return true
    }
}
