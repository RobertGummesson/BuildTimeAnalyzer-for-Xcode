//
//  XcodeDatabase.swift
//  BuildTimeAnalyzer
//

import Foundation
import Compression

struct XcodeDatabase {
    var path: String
    var modificationDate: Date
    
    var key: String
    var schemeName: String
    var title: String
    var timeStartedRecording: Int
    var timeStoppedRecording: Int
    
    var isBuildType: Bool {
        return title.hasPrefix("Build ") ||  title.hasPrefix("Compile ")
    }
    
    var url: URL {
        return URL(fileURLWithPath: path)
    }
    
    var logUrl: URL {
        return folderPath.appendingPathComponent("\(key).xcactivitylog")
    }
    
    var folderPath: URL {
        return url.deletingLastPathComponent()
    }
    
    var buildTime: Int {
        return timeStoppedRecording - timeStartedRecording
    }
    
    init?(fromPath path: String) {
        guard let data = NSDictionary(contentsOfFile: path)?["logs"] as? [String: AnyObject],
            let key = XcodeDatabase.sortKeys(usingData: data).last?.key,
            let value = data[key] as? [String : AnyObject],
            let schemeName = value["schemeIdentifier-schemeName"] as? String,
            let title = value["title"] as? String,
            let timeStartedRecording = value["timeStartedRecording"] as? NSNumber,
            let timeStoppedRecording = value["timeStoppedRecording"] as? NSNumber,
            let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path),
            let modificationDate = fileAttributes[FileAttributeKey.modificationDate] as? Date
            else { return nil }
        
        self.modificationDate = modificationDate
        self.path = path
        self.key = key
        self.schemeName = schemeName
        self.title = title
        self.timeStartedRecording = timeStartedRecording.intValue
        self.timeStoppedRecording = timeStoppedRecording.intValue
    }
    
    func processLog() -> String? {
        guard let rawData = try? Data(contentsOf: URL(fileURLWithPath: logUrl.path)),
              let data = rawData.gunzipped() else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private static let gzipHeaderSize = 10
    
    static func gunzip(_ data: Data) -> Data? {
        guard data.count > gzipHeaderSize else { return nil }
        
        // Skip the gzip header (10 bytes) to get raw deflate data
        let deflateData = data.dropFirst(gzipHeaderSize)
        
        let bufferSize = data.count * 4
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var result = Data()
        deflateData.withUnsafeBytes { rawBuffer in
            guard let sourcePointer = rawBuffer.baseAddress?.bindMemory(to: UInt8.self, capacity: deflateData.count) else { return }
            let stream = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
            defer { stream.deallocate() }
            
            var status = compression_stream_init(stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status == COMPRESSION_STATUS_OK else { return }
            defer { compression_stream_destroy(stream) }
            
            stream.pointee.src_ptr = sourcePointer
            stream.pointee.src_size = deflateData.count
            stream.pointee.dst_ptr = buffer
            stream.pointee.dst_size = bufferSize
            
            repeat {
                status = compression_stream_process(stream, 0)
                if stream.pointee.dst_size == 0 || status == COMPRESSION_STATUS_END {
                    let outputSize = bufferSize - stream.pointee.dst_size
                    result.append(buffer, count: outputSize)
                    stream.pointee.dst_ptr = buffer
                    stream.pointee.dst_size = bufferSize
                }
            } while status == COMPRESSION_STATUS_OK
        }
        return result.isEmpty ? nil : result
    }
    
    static private func sortKeys(usingData data: [String: AnyObject]) -> [(Int, key: String)] {
        var sortedKeys: [(Int, key: String)] = []
        for key in data.keys {
            if let value = data[key] as? [String: AnyObject],
                let timeStoppedRecording = value["timeStoppedRecording"] as? NSNumber {
                sortedKeys.append((timeStoppedRecording.intValue, key))
            }
        }
        return sortedKeys.sorted{ $0.0 < $1.0 }
    }
}

private extension Data {
    func gunzipped() -> Data? {
        return XcodeDatabase.gunzip(self)
    }
}

extension XcodeDatabase : Equatable {}

func ==(lhs: XcodeDatabase, rhs: XcodeDatabase) -> Bool {
    return lhs.path == rhs.path && lhs.modificationDate == rhs.modificationDate
}
