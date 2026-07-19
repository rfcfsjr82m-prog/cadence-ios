import SwiftUI

struct FilterPillsView: View {
    @Binding var selected: Category?
    /// Which categories to show. Defaults to all — pass a subset for personal tab.
    var categories: [Category] = Category.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Pill(label: "All", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(categories) { cat in
                    Pill(label: cat.displayName, isSelected: selected == cat) {
                        selected = cat
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct Pill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(label))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accent : Color.surface2)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color.borderDefault,
                                      lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
