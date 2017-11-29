//
//  UserCache.swift
//  BuildTimeAnalyzer
//

import Foundation

class UserSettings {
    
    static private let derivedDataLocationKey = "derivedDataLocationKey"
    static private let windowLevelIsNormalKey = "windowLevelIsNormalKey"
    
    static private var _derivedDataLocation: String?
    static private var _windowLevelIsNormal: Bool?
    
    static var derivedDataLocation: String {
        get {
            if _derivedDataLocation == nil {
                _derivedDataLocation = UserDefaults.standard.string(forKey: derivedDataLocationKey)
            }
            if _derivedDataLocation == nil, let libraryFolder = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first {
                _derivedDataLocation = "\(libraryFolder)/Developer/Xcode/DerivedData"
            }
            return _derivedDataLocation ?? ""
        }
        set {
            _derivedDataLocation = newValue
            UserDefaults.standard.set(newValue, forKey: derivedDataLocationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    static var windowShouldBeTopMost: Bool {
        get {
            if _windowLevelIsNormal == nil {
                _windowLevelIsNormal = UserDefaults.standard.bool(forKey: windowLevelIsNormalKey)
            }
            return !(_windowLevelIsNormal ?? false)
        }
        set {
            _windowLevelIsNormal = !newValue
            UserDefaults.standard.set(_windowLevelIsNormal, forKey: windowLevelIsNormalKey)
            UserDefaults.standard.synchronize()
        }
    }
}
