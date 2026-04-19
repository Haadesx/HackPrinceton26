import SwiftUI

@MainActor
final class KnowledgeGraphViewModel: ObservableObject {
    @Published var nodes: [ConceptNode] = []
    @Published var edges: [ConceptEdge] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedNode: ConceptNode?
    @Published var selectedCourse: String? = nil
    @Published var isUsingDemoData = false

    var courses: [String] { Array(Set(nodes.map { $0.course_id })).sorted() }

    var filteredNodes: [ConceptNode] {
        guard let course = selectedCourse else { return nodes }
        return nodes.filter { $0.course_id == course }
    }

    var filteredEdges: [ConceptEdge] {
        let nodeIDs = Set(filteredNodes.map { $0.id })
        return edges.filter { nodeIDs.contains($0.source) && nodeIDs.contains($0.target) }
    }

    func load() async {
        isLoading = true
        error = nil
        isUsingDemoData = false
        do {
            async let n = APIClient.shared.fetchConcepts()
            async let e = APIClient.shared.fetchConnections()
            (nodes, edges) = try await (n, e)
        } catch {
            nodes = DemoContent.conceptNodes
            edges = DemoContent.conceptEdges
            isUsingDemoData = true
        }
        isLoading = false
    }

    func relatedEdges(for node: ConceptNode) -> [ConceptEdge] {
        edges.filter { $0.source == node.id || $0.target == node.id }
    }

    func nodeForID(_ id: String) -> ConceptNode? {
        nodes.first { $0.id == id }
    }
}

struct KnowledgeGraphView: View {
    @StateObject private var vm = KnowledgeGraphViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    LoadingView(message: "Loading concept graph…")
                } else if let err = vm.error {
                    ErrorView(message: err, retry: { Task { await vm.load() } })
                } else {
                    content
                }
            }
            .navigationTitle("Knowledge Graph")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.bgBase)
        }
        .task { await vm.load() }
    }

    private var content: some View {
        VStack(spacing: 0) {
            courseFilter
            if vm.isUsingDemoData {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.scarlet)
                    Text("Showing offline graph data because the live graph could not be loaded.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            if vm.filteredNodes.isEmpty {
                Spacer()
                Text("No concepts found.")
                    .foregroundColor(.textTertiary)
                    .font(.system(size: 14))
                Spacer()
            } else {
                graphBody
            }
        }
    }

    private var courseFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", value: nil)
                ForEach(vm.courses, id: \.self) { course in
                    filterChip(label: course.uppercased(), value: course)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.bgBase)
    }

    private func filterChip(label: String, value: String?) -> some View {
        let active = vm.selectedCourse == value
        return Button { vm.selectedCourse = value } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(active ? .white : .textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.scarlet : Color.bgCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? Color.clear : Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    private var graphBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Lateral card grid of concept nodes
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(vm.filteredNodes) { node in
                        ConceptNodeCard(
                            node: node,
                            edges: vm.relatedEdges(for: node),
                            allNodes: vm.nodes,
                            isSelected: vm.selectedNode?.id == node.id
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                vm.selectedNode = vm.selectedNode?.id == node.id ? nil : node
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Selected node detail
                if let node = vm.selectedNode {
                    selectedNodeDetail(node)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func selectedNodeDetail(_ node: ConceptNode) -> some View {
        let related = vm.relatedEdges(for: node)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(node.course_id.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.textTertiary)
                }
                Spacer()
                Button { vm.selectedNode = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.textTertiary)
                }
            }
            Text(node.description)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .lineSpacing(3)

            if !related.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONNECTIONS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.textTertiary)
                        .tracking(1.2)
                    ForEach(Array(related.enumerated()), id: \.offset) { _, edge in
                        let otherID = edge.source == node.id ? edge.target : edge.source
                        let other = vm.nodeForID(otherID)
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.scarlet)
                            Text(edge.relationship)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.textTertiary)
                            Text(other?.label ?? otherID)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.bgSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.scarlet.opacity(0.3), lineWidth: 1))
    }
}

struct ConceptNodeCard: View {
    let node: ConceptNode
    let edges: [ConceptEdge]
    let allNodes: [ConceptNode]
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(Color.scarletMuted).frame(width: 28, height: 28)
                    Image(systemName: "circle.hexagonpath")
                        .font(.system(size: 13))
                        .foregroundColor(.scarlet)
                }
                Spacer()
                Text("\(edges.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.bgSurface)
                    .clipShape(Capsule())
            }
            Text(node.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(2)
            Text(node.course_id.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .tracking(0.8)
        }
        .padding(12)
        .background(isSelected ? Color.scarletMuted : Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.scarlet.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
