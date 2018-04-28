//
//  XcodeDatabase.swift
//  BuildTimeAnalyzer
//

import Foundation

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
            let modificationDate = fileAttributes[.modificationDate] as? Date
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
        if let rawData = try? Data(contentsOf: URL(fileURLWithPath: logUrl.path)),
            let data = (rawData as NSData).gunzipped() {
            return String(data: data, encoding: String.Encoding.utf8)
        }
        return nil
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

extension XcodeDatabase : Equatable {}

func ==(lhs: XcodeDatabase, rhs: XcodeDatabase) -> Bool {
    return lhs.path == rhs.path && lhs.modificationDate == rhs.modificationDate
}
