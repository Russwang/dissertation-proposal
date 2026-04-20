import Foundation
import PDFKit

func usage() {
    let text = """
    用法:
      swift -module-cache-path /tmp/swift-module-cache tools/extract_pdf_text.swift <input.pdf> [output.txt] [max_pages]

    说明:
      - 不传 output.txt 时输出到标准输出
      - max_pages 默认提取全部页面
    """
    print(text)
}

let args = CommandLine.arguments.dropFirst()
guard let inputPath = args.first else {
    usage()
    exit(1)
}

let outputPath = args.dropFirst().first
let maxPagesArg = args.dropFirst(2).first
let maxPages = maxPagesArg.flatMap(Int.init)

let inputURL = URL(fileURLWithPath: inputPath)
guard let document = PDFDocument(url: inputURL) else {
    fputs("无法打开 PDF: \(inputPath)\n", stderr)
    exit(2)
}

var output = ""
output += "SOURCE: \(inputPath)\n"
output += "PAGES: \(document.pageCount)\n\n"

let pageLimit = min(document.pageCount, maxPages ?? document.pageCount)
for index in 0..<pageLimit {
    output += "=== PAGE \(index + 1) ===\n"
    output += document.page(at: index)?.string ?? ""
    output += "\n\n"
}

if let outputPath {
    let outputURL = URL(fileURLWithPath: outputPath)
    let dirURL = outputURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
    do {
        try output.write(to: outputURL, atomically: true, encoding: .utf8)
    } catch {
        fputs("写入失败: \(outputPath)\n", stderr)
        exit(3)
    }
} else {
    print(output)
}
