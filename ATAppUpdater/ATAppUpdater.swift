//
//  ATAppUpdater.swift
//  R8Me
//
//  Created by Michael Gasparik on 22/11/15.
//  Copyright © 2015 Michael Gasparik. All rights reserved.
//

import UIKit
import SystemConfiguration

class ATAppUpdater : NSObject, UIAlertViewDelegate {
    
    var alertTitle : String
    var alertMessage : String
    var alertUpdateButtonTitle : String
    var alertCancelButtonTitle : String
    
    class func sharedUpdater() -> ATAppUpdater {
        struct Static {
            static let instance: ATAppUpdater = ATAppUpdater()
        }
        return Static.instance
    }

    required override init() {
        self.alertTitle = "New Version"
        self.alertMessage = "Version %@ is available on the AppStore."
        self.alertUpdateButtonTitle = "Update"
        self.alertCancelButtonTitle = "Not Now"
        
        super.init()
    }
    
    func showUpdateWithForce() {
        let hasConnection: Bool = self.hasConnection()
        if !hasConnection {
            return
        }
        checkNewAppVersion({(newVersion, version) in
            if newVersion {
                self.alertUpdateForVersion(version!, withForce: true).show()
            }
            
        })
    }
    
    func showUpdateWithForce(minimumForceVersion : String?) {
        let hasConnection: Bool = self.hasConnection()
        if !hasConnection {
            return
        }
        checkNewAppVersion({(newVersion, version) in
            if newVersion {
                if(minimumForceVersion != nil){
                    let bundleInfo = NSBundle.mainBundle().infoDictionary
                    let currentVersion : String = bundleInfo!["CFBundleShortVersionString"] as! String
                    if minimumForceVersion!.compare(currentVersion, options: .NumericSearch) == .OrderedDescending {
                        self.alertUpdateForVersion(version!, withForce: true).show()
                        return
                    }
                }
                self.alertUpdateForVersion(version!, withForce: false).show()
            }
        })
    }
    
    func showUpdateWithConfirmation() {
        let hasConnection: Bool = self.hasConnection()
        if !hasConnection {
            return
        }
        checkNewAppVersion({(newVersion, version) in
            if newVersion {
                self.alertUpdateForVersion(version!, withForce: false).show()
            }
        })
    }
    
    func forceOpenNewAppVersion(force: Bool) {
        let hasConnection: Bool = self.hasConnection()
        if !hasConnection {
            return
        }
        checkNewAppVersion({(newVersion, version) in
            if newVersion {
                self.alertUpdateForVersion(version!, withForce: force).show()
            }
            
        })
    }
    
    func hasConnection() -> Bool {
        let host = "itunes.apple.com"
        var success: Bool
        let reachability: SCNetworkReachabilityRef = SCNetworkReachabilityCreateWithName(nil, host)!
        var flags : SCNetworkReachabilityFlags = []
        success = SCNetworkReachabilityGetFlags(reachability, &flags)
        
        if !success {
            return false
        }
        
        let isReachable = flags.contains(.Reachable)
        let needsConnection = flags.contains(.ConnectionRequired)
        return (isReachable && !needsConnection)
    }
    var appStoreURL: String? = nil
    
    func checkNewAppVersion(completion: (newVersion : Bool, version : String?) -> Void ) {
        if let bundleInfo = NSBundle.mainBundle().infoDictionary {
            
            let bundleIdentifier = bundleInfo["CFBundleIdentifier"] as! String
            let currentVersion : String = bundleInfo["CFBundleShortVersionString"] as! String
            let lookupURL: NSURL = NSURL(string: "http://itunes.apple.com/lookup?bundleId=\(bundleIdentifier)")!
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), {() in
                if let lookupResults: NSData = NSData(contentsOfURL: lookupURL) {
                    
                    do {
                        var jsonResults: [NSObject : AnyObject] = try NSJSONSerialization.JSONObjectWithData(lookupResults, options: NSJSONReadingOptions.MutableContainers) as! [NSObject : AnyObject]
                        dispatch_async(dispatch_get_main_queue(), {() in
                            let resultCount: Int = jsonResults["resultCount"] as! Int
                            if resultCount > 0 {
                                var appDetails: [NSObject : AnyObject] = jsonResults["results"]!.firstObject as! [NSObject : AnyObject]
                                let appItunesUrl: String = appDetails["trackViewUrl"]!.stringByReplacingOccurrencesOfString("&uo=4", withString: "")
                                let latestVersion: String = appDetails["version"] as! String
                                
                                if latestVersion.compare(currentVersion, options: .NumericSearch) == .OrderedDescending {
                                    self.appStoreURL = appItunesUrl
                                    completion(newVersion: true, version: latestVersion)
                                }
                                else {
                                    completion(newVersion: false, version: nil)
                                }
                            }
                            else {
                                completion(newVersion: false, version: nil)
                            }
                            
                        })
                    } catch {
                        
                    }
                } else {
                    completion(newVersion: false, version: nil)
                    return
                }
            })
        }
    }
    
    func alertUpdateForVersion(version: String, withForce force: Bool) -> UIAlertView {
        let msg: String = String(format: alertMessage, version)
        let alert: UIAlertView = UIAlertView(title: alertTitle, message: msg, delegate: self, cancelButtonTitle: force ? nil : alertUpdateButtonTitle, otherButtonTitles: force ? alertUpdateButtonTitle : alertCancelButtonTitle)
        return alert
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 0 {
            let appUrl: NSURL = NSURL(string: appStoreURL!)!
            if UIApplication.sharedApplication().canOpenURL(appUrl) {
                UIApplication.sharedApplication().openURL(appUrl)
            }
            else {
                let cantOpenUrlAlert: UIAlertView = UIAlertView(title: "Not Available", message: "Could not open the AppStore, please try again later.", delegate: nil, cancelButtonTitle: "OK")
                
                cantOpenUrlAlert.show()
            }
        }
    }
}