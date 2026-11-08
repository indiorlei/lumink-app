import SwiftUI

struct JobRowView: View {
    @Environment(QueueViewModel.self) private var queue
    @Bindable var job: BookJob

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch job.status {
            case .pendingReview:
                MetadataEditor(job: job) { queue.start(job) }
            case .queued, .running:
                StageIndicator(current: job.stage)
                progressBar
            case .succeeded(let message):
                resultLine(ok: true, message: message)
            case .failed(let message):
                resultLine(ok: false, message: message)
            case .cancelled:
                resultLine(ok: false, message: "Cancelado.")
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Mostrar no Finder") { queue.showInFinder(job) }
            Button("Remover da lista") { queue.remove(job) }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(Format.bytes(job.originalSize))
                    if let final = job.finalSize {
                        Image(systemName: "arrow.right")
                        Text(Format.bytes(final)).bold()
                    }
                    if !job.detail.isEmpty {
                        Text("·")
                        Text(job.detail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            trailingButtons
        }
    }

    @ViewBuilder
    private var trailingButtons: some View {
        switch job.status {
        case .queued, .running:
            Button("Cancelar") { queue.cancel(job) }
                .controlSize(.small)
        case .succeeded, .failed, .cancelled:
            HStack {
                if job.status != .cancelled, job.outputURL != nil {
                    Button("Mostrar no Finder") { queue.showInFinder(job) }
                }
                if case .succeeded = job.status {} else {
                    Button("Tentar de novo") { queue.retry(job) }
                }
            }
            .controlSize(.small)
        case .pendingReview:
            Button {
                queue.remove(job)
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remover da fila")
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if job.status == .queued {
            Text("Na fila…").font(.caption).foregroundStyle(.secondary)
        } else if let p = job.progress {
            ProgressView(value: p)
        } else {
            ProgressView().progressViewStyle(.linear)
        }
    }

    private func resultLine(ok: Bool, message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(ok ? "✅" : "❌")
            Text(message)
                .font(.callout)
                .foregroundStyle(ok ? Color.primary : Color.red)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct StageIndicator: View {
    let current: PipelineStage

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(PipelineStage.visible.enumerated()), id: \.element) { index, stage in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(stage.label)
                    .font(.caption.weight(stage == current ? .semibold : .regular))
                    .foregroundStyle(color(for: stage))
            }
        }
    }

    private func color(for stage: PipelineStage) -> Color {
        if stage == current { return .accentColor }
        return stage.rawValue < current.rawValue ? .secondary : Color(nsColor: .tertiaryLabelColor)
    }
}

enum Format {
    static func bytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
