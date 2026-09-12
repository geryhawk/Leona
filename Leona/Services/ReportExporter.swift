import Foundation
import UIKit
import CoreText

/// Turns the thread into files a parent can hand to someone else:
/// an A4 PDF of the full report and a CSV of every entry.
/// Both land in the temporary directory; the caller shares the returned URL.
enum ReportExporter {

    // MARK: - PDF

    static func makeReportPDF(
        baby: Baby,
        activities: [Activity],
        growthRecords: [GrowthRecord],
        healthRecords: [HealthRecord]
    ) -> URL? {
        let text = ExportService.generateFullReport(
            baby: baby,
            activities: activities,
            growthRecords: growthRecords,
            healthRecords: healthRecords
        )
        let url = temporaryURL(baby: baby, ext: "pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in points
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: pdfFormat(baby: baby))

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor(hex: 0x1C1520)
        ]
        let title = NSAttributedString(string: "Leona · \(baby.displayName)", attributes: titleAttributes)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor(hex: 0x1C1520),
            .paragraphStyle: paragraph
        ]
        let body = NSAttributedString(string: text, attributes: bodyAttributes)
        let framesetter = CTFramesetterCreateWithAttributedString(body)

        do {
            try renderer.writePDF(to: url) { context in
                var range = CFRange(location: 0, length: 0)
                var isFirstPage = true

                repeat {
                    context.beginPage()
                    var textRect = pageRect.insetBy(dx: margin, dy: margin)

                    if isFirstPage {
                        let titleHeight = title.size().height
                        title.draw(at: CGPoint(x: textRect.minX, y: textRect.minY))
                        let rule = UIBezierPath()
                        rule.move(to: CGPoint(x: textRect.minX, y: textRect.minY + titleHeight + 8))
                        rule.addLine(to: CGPoint(x: textRect.maxX, y: textRect.minY + titleHeight + 8))
                        UIColor(hex: 0xE24E2B).setStroke()
                        rule.lineWidth = 1.5
                        rule.stroke()
                        let used = titleHeight + 22
                        textRect.origin.y += used
                        textRect.size.height -= used
                    }

                    let cg = context.cgContext
                    cg.saveGState()
                    cg.textMatrix = .identity
                    cg.translateBy(x: 0, y: pageRect.height)
                    cg.scaleBy(x: 1, y: -1)
                    let flipped = CGRect(
                        x: textRect.minX,
                        y: pageRect.height - textRect.maxY,
                        width: textRect.width,
                        height: textRect.height
                    )
                    let frame = CTFramesetterCreateFrame(framesetter, range, CGPath(rect: flipped, transform: nil), nil)
                    CTFrameDraw(frame, cg)
                    cg.restoreGState()

                    let visible = CTFrameGetVisibleStringRange(frame)
                    guard visible.length > 0 else { break }
                    range = CFRange(location: visible.location + visible.length, length: 0)
                    isFirstPage = false
                } while range.location < body.length
            }
        } catch {
            return nil
        }
        return url
    }

    // MARK: - CSV

    static func makeCSV(baby: Baby, activities: [Activity]) -> URL? {
        let csv = ExportService.exportToCSV(baby: baby, activities: activities)
        let url = temporaryURL(baby: baby, ext: "csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return nil
        }
        return url
    }

    // MARK: - Helpers

    private static func pdfFormat(baby: Baby) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Leona · \(baby.displayName)",
            kCGPDFContextCreator as String: "Leona"
        ]
        return format
    }

    private static func temporaryURL(baby: Baby, ext: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let stamp = formatter.string(from: Date())
        let name = safeFileComponent(baby.displayName)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("Leona-\(name)-\(stamp)")
            .appendingPathExtension(ext)
    }

    private static func safeFileComponent(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let cleaned = String(String.UnicodeScalarView(allowed))
        return cleaned.isEmpty ? "baby" : cleaned
    }
}
