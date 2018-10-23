import Foundation
import Bits

final class DecoderDataContainer {
    var allKeys: [CodingKey]?
    let data: [UInt8]

    private(set) var row: [String: Bytes]!
    private(set) var cell: Bytes?
    private(set) var header: [String]

    private var dataIndex: Int

    init(data: [UInt8]) throws {
        allKeys = nil
        row = [:]
        cell = nil

        self.data = data
        header = []
        dataIndex = data.startIndex

        try configure()
    }

    private func configure() throws {
        header.reserveCapacity(
            data.lazy.split(separator: .newLine).first?.reduce(0) {
                $1 == .comma ? $0 + 1 : $0
            } ?? 0
        )

        var cellStart = dataIndex
        var cellEnd = dataIndex
        var inQuote = false

        header: while dataIndex < data.endIndex {
            let byte = data[dataIndex]

            switch byte {
            case .quote:
                inQuote = !inQuote
                cellEnd += 1
            case .comma:
                if inQuote { fallthrough }
                var cell = Array(data[cellStart...cellEnd-1])
                cell.removeAll { $0 == .quote }
                try header.append(String(cell))

                cellStart = dataIndex + 1
                cellEnd = dataIndex + 1
            case .newLine, .carriageReturn:
                if inQuote { fallthrough }
                var cell = Array(data[cellStart...cellEnd-1])
                cell.removeAll { $0 == .quote }
                try header.append(String(cell))

                dataIndex = byte == .newLine ? dataIndex + 1 : dataIndex + 2
                break header
            default:
                cellEnd += 1
            }

            dataIndex += 1
        }

        row.reserveCapacity(header.count)
    }

    func cell(for key: CodingKey) {
        cell = row[key.stringValue]
    }

    func incrementRow() {
        guard dataIndex < data.endIndex else {
            row = nil
            return
        }

        var cellStart = dataIndex
        var cellEnd = dataIndex
        var inQuote = false
        var columnIndex = 0

        while dataIndex < data.endIndex {
            let byte = data[dataIndex]
            switch byte {
            case .quote:
                inQuote = !inQuote
                cellEnd += 1
            case .comma:
                if inQuote { fallthrough }

                // Empty column
                guard cellEnd - cellStart >= 1 else {
                    break
                }

                var cell = Array(data[cellStart...cellEnd-1])
                cell.removeAll { $0 == .quote }
                row[header[columnIndex]] = cell

                cellStart = dataIndex + 1
                cellEnd = dataIndex + 1
                columnIndex += 1
            case .newLine, .carriageReturn:
                if inQuote { fallthrough }
                var cell = Array(data[cellStart...cellEnd-1])
                cell.removeAll { $0 == .quote }
                row[header[columnIndex]] = cell

                dataIndex = byte == .newLine ? dataIndex + 1 : dataIndex + 2
                return
            default:
                cellEnd += 1
            }

            dataIndex += 1
        }
    }
}
