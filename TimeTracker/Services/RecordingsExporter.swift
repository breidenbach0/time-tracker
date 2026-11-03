import AppKit

/// Writes recordings to a PDF report in the exports folder.
enum RecordingsExporter {
    static func writePDF(
        for exportEntries: [TimeEntry],
        from startDate: Date,
        to endDate: Date,
        projectFilter: String
    ) throws -> URL {
        DatabaseManager.ensureStorageDirectories()

        let report = reportText(for: exportEntries, periodTitle: rangeTitle(from: startDate, to: endDate), projectFilter: projectFilter)
        let slug = rangeSlug(from: startDate, to: endDate)
        let fileName = "timetracker-\(slug)-\(dateStamp).pdf"
        let fileURL = DatabaseManager.exportsDirectoryURL.appendingPathComponent(fileName)
        let pdfData = try buildPDF(from: report)
        try pdfData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func rangeTitle(from startDate: Date, to endDate: Date) -> String {
        let formatter = DisplayFormatter.formatter(pattern: "dd.MM.yyyy")
        return "\(formatter.string(from: min(startDate, endDate))) - \(formatter.string(from: max(startDate, endDate)))"
    }

    private static func reportText(for exportEntries: [TimeEntry], periodTitle: String, projectFilter: String) -> String {
        let dateFormatter = DisplayFormatter.formatter(pattern: "dd.MM.yy")
        let timeFormatter = DisplayFormatter.formatter(pattern: "HH:mm")

        let rows = exportEntries.sorted(by: { $0.startDate > $1.startDate }).map { entry in
            let start = timeFormatter.string(from: entry.startDate)
            let end = entry.endDate.map { timeFormatter.string(from: $0) } ?? "-"
            let entryDate = dateFormatter.string(from: entry.startDate)
            let noteText = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let hours = Int(entry.duration) / 3600
            let minutes = (Int(entry.duration) % 3600) / 60
            let seconds = Int(entry.duration) % 60
            let totalWorked = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

            return """
            \(entry.name)
            Note: \(noteText.isEmpty ? "-" : noteText)
            Date: \(entryDate)
            Start: \(start)
            End: \(end)
            Total Worked: \(totalWorked)
            """
        }

        return """
        TimeTracker Export
        Period: \(periodTitle)
        Project Filter: \(projectFilter)
        Exported: \(dateStamp)

        \(rows.joined(separator: "\n\n"))
        """
    }

    private static func rangeSlug(from startDate: Date, to endDate: Date) -> String {
        let formatter = DisplayFormatter.formatter(pattern: "yyyy-MM-dd")
        return "\(formatter.string(from: min(startDate, endDate)))-to-\(formatter.string(from: max(startDate, endDate)))"
    }

    private static func buildPDF(from report: String) throws -> Data {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.black
        ]
        let attributedText = NSAttributedString(string: report, attributes: attributes)
        let textRect = attributedText.boundingRect(
            with: NSSize(width: 523, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let reportHeight = max(842, ceil(textRect.height) + 72)
        let reportView = ExportReportView(
            frame: NSRect(x: 0, y: 0, width: 595, height: reportHeight),
            attributedText: attributedText
        )

        return reportView.dataWithPDF(inside: reportView.bounds)
    }

    private static var dateStamp: String {
        DisplayFormatter.formatter(pattern: "yyyy-MM-dd-HHmm").string(from: Date())
    }
}

private final class ExportReportView: NSView {
    private let attributedText: NSAttributedString

    override var isFlipped: Bool {
        true
    }

    init(frame frameRect: NSRect, attributedText: NSAttributedString) {
        self.attributedText = attributedText
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        attributedText.draw(in: NSRect(x: 36, y: 36, width: bounds.width - 72, height: bounds.height - 72))
    }
}
