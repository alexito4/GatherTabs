//
//  main.swift
//  GatherTabs
//
//  Copyright © 2016 Alejandro Martinez. All rights reserved.
//

import Foundation

// MARK: Helpers

func asNSDictionary(object: AnyObject) -> NSDictionary {
    return object as! NSDictionary
}
func asNSArray(object: AnyObject) -> NSArray {
    return object as! NSArray
}
func asNSMutableArray(object: AnyObject) -> NSMutableArray {
    return object as! NSMutableArray
}

// MARK: Paths and Constants
// let SafariReadingListId = "com.apple.ReadingList"

let home = NSHomeDirectory()

let LocalPlistPath = home + "/Library/Safari/LastSession.plist"
let SyncPlistPath = home + "/Library/SyncedPreferences/com.apple.Safari.plist"
let RequestPath = home + "/Library/SyncedPreferences/com.apple.Safari-com.apple.Safari.UserRequests.plist"


let DeviceName = NSHost.currentHost().localizedName!

// MARK: Load PLISTs

guard var SyncPlist = NSDictionary(contentsOfFile: SyncPlistPath) else {
    fatalError("Sync Plist not found.")
}

guard var SessionPlist = NSMutableDictionary(contentsOfFile: LocalPlistPath) else {
    fatalError("Last Session Plist not found.")
}

// MARK: Get current Session tabs

print("This script will add all the tabs from other devices to one window of this device.")

// Add the gathered synced tabs to the local session
var allWindows = SessionPlist["SessionWindows"].map(asNSMutableArray)!
var firstWindow = allWindows[0] as! Dictionary<String, AnyObject>
var tabStates = firstWindow["TabStates"]! as! Array<NSDictionary>
print("> \(tabStates.count) tabs in the current session")

// MARK: Gather synced tabs

func convertTab(original: NSDictionary) -> NSDictionary {
    let res = tabStates[0].mutableCopy() as! NSMutableDictionary
    res["TabURL"] = original["URL"] as! String
    res["TabUUID"] = original["UUID"] as! String
    res["TabTitle"] = original["Title"] as! String
    res["SessionState"] = NSData()
    return res
}

// Need to keep track of the tabs to remove
var toRemove = Dictionary<String, AnyObject>()

// Values Dictionary. Device ID -> Device
var values = SyncPlist["values"]! as! NSDictionary

// Grab array of Device IDs
var allDevicesIds = values.allKeys as! [String]

// Filter current Device
func deviceName(id: String) -> String {
    let device = values[id] as! NSDictionary
    let info = device["value"] as! NSDictionary
    let name = info["DeviceName"] as! String
    return name
}
let devicesIds = allDevicesIds.filter({
    let name = deviceName($0)
    return name != DeviceName
})
let localId = allDevicesIds.filter({
    let name = deviceName($0)
    return name == DeviceName
}).first!

// Tabs with the format of the LastSession.plist
var transformedTabs = [NSDictionary]()

// Process the tabs in the remote devices
// A previous version did this more FP, but because the need of doing different operations 
// is more understandable in imperative.
for id in devicesIds {
    let device = (values[id] as! NSDictionary)["value"] as! NSDictionary
    let tabs = device["Tabs"] as! NSArray
    
    for tab in tabs {
        // Gather tab
        let transformedTab = convertTab(tab as! NSDictionary)
        transformedTabs.append(transformedTab)
        
        // Create the Remove request
        let value = [
            "DictionaryType" : "CloseTabRequest",
            "TabURL": transformedTab["TabURL"] as! String,
            "LastModified": NSDate(),
            "TabUUID" : transformedTab["TabUUID"] as! String,
            "DestinationDeviceUUID": id,
            "SourceDeviceUUID" : localId
        ]
        let request = [
            "value": value,
            "remotevalue": NSData(),
            "timestamp": 0
        ]
        toRemove[NSUUID().UUIDString] = request
    }
}

print("> \(transformedTabs.count) tabs found across all your other devices.")

// MARK: Add gathered tabs to current session
tabStates.appendContentsOf(transformedTabs)
print("> Local session now has \(tabStates.count) tabs.")

// MARK: Update Session Plist with new tabs and Save
firstWindow["TabStates"] = tabStates
allWindows[0] = firstWindow
SessionPlist["SessionWindows"] = allWindows

//guard SessionPlist.writeToFile(LocalPlistPath, atomically: true) else {
//    fatalError("ERROR when saving the local session. Aborting.")
//}

// MARK: Remove gathered tabs from the remote devices
// Removing the remote tabs doesn't work.
// Adding this request to the plist doesn't do the job.
// Maybe is the timestamp, or the remotevalue?
/*
print("> Removing gathered tabs from the remote devices.")
guard var RequestPlist = NSMutableDictionary(contentsOfFile: RequestPath) else {
    fatalError("Request Plist not found.")
}
RequestPlist.setValue(toRemove.count + (RequestPlist["changecount"]! as! Int), forKey: "changecount")
RequestPlist["values"] = toRemove
guard RequestPlist.writeToFile(RequestPath, atomically: true) else {
    fatalError("ERROR when saving the Request Plist. Aborting.")
}
*/

print("Open Safari now. The new Tabs aren't precached. They will be loaded when you first open them.")





