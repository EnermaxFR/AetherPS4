import SwiftUI
import UniformTypeIdentifiers

enum LibrarySortOrder: String, CaseIterable {
    case nameAscending = "Nom (A–Z)"
    case nameDescending = "Nom (Z–A)"
    case dateAddedNewest = "Ajoutés récemment"
    case dateAddedOldest = "Ajoutés en premier"
}

struct LibraryView: View {
    @Environment(GameLibrary.self) private var library
    @State private var searchText = ""
    @State private var sortOrder: LibrarySortOrder = .dateAddedNewest
    @State private var isImporterPresented = false

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)]

    private var visibleGames: [Game] {
        let filtered: [Game]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filtered = library.games
        } else {
            filtered = library.games.filter { game in
                game.name.localizedCaseInsensitiveContains(searchText)
                    || (game.titleId?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortOrder {
        case .nameAscending:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        case .dateAddedNewest:
            return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .dateAddedOldest:
            return filtered.sorted { $0.dateAdded < $1.dateAdded }
        }
    }

    var body: some View {
        Group {
            if library.isImporting {
                importingState
            } else if library.games.isEmpty {
                emptyState
            } else if visibleGames.isEmpty {
                noResultsState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(visibleGames) { game in
                            NavigationLink(value: game) {
                                GameCardView(game: game, isSelected: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Jeux")
        .navigationDestination(for: Game.self) { game in
            GameDetailView(game: game)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Rechercher un jeu"
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Trier", selection: $sortOrder) {
                        ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Label("Trier", systemImage: "arrow.up.arrow.down")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    library.refresh()
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Ajouter un jeu", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(library.isImporting)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pkgPackage],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await library.importPkg(from: url) }
        }
        .alert(
            "Impossible d’ajouter le jeu",
            isPresented: Binding(
                get: { library.lastImportError != nil },
                set: { if !$0 { library.lastImportError = nil } }
            )
        ) {
            Button("OK") { library.lastImportError = nil }
        } message: {
            Text(library.lastImportError ?? "")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Aucun jeu")
                .font(.headline)
            Text("Touchez + pour importer un fichier .pkg.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var importingState: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Installation du jeu…")
                .font(.headline)
            Text("MaxPS4 prépare le package. Gardez l’application ouverte pendant l’opération.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Aucun résultat pour « \(searchText) »")
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension UTType {
    static var pkgPackage: UTType {
        UTType(filenameExtension: "pkg") ?? .data
    }
}
