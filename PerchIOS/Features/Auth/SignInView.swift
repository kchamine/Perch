import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var isShowingSignUp = false
    @FocusState private var focusedField: AuthField?

    var body: some View {
        NavigationStack {
            if isShowingSignUp {
                SignUpView(isShowingSignUp: $isShowingSignUp)
                    .environmentObject(authStore)
            } else {
                authForm
            }
        }
    }

    private var authForm: some View {
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
                isShowingSignUp = true
            } label: {
                Text("Create an account")
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
            Text("Perch")
                .font(PerchTheme.headline(42))
                .foregroundStyle(PerchTheme.primary)
            Text("Sign in to keep your places, reviews, and saved spots tied to your account.")
                .font(.headline)
                .foregroundStyle(PerchTheme.textMuted)
                .lineSpacing(3)
        }
        .padding(.top, 40)
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in")
                .font(PerchTheme.headline(28))
                .foregroundStyle(PerchTheme.primary)

            authTextField("Email", text: $email, keyboard: .emailAddress)
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focusedField, equals: .password)
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
                    Text(isSubmitting ? "Signing in..." : "Sign in")
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
                try await authStore.signIn(email: email, password: password)
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
        guard !password.isEmpty else {
            errorMessage = "Enter your password."
            focusedField = .password
            return false
        }
        return true
    }
}

enum AuthField: Hashable {
    case email
    case password
    case confirmPassword
}

func authTextField(
    _ title: String,
    text: Binding<String>,
    keyboard: UIKeyboardType = .default
) -> some View {
    TextField(title, text: text)
        .keyboardType(keyboard)
        .textContentType(title == "Email" ? .emailAddress : nil)
        .autocorrectionDisabled()
        .padding(14)
        .background(PerchTheme.controlFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
}
