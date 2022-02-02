//
//  AppDelegate.swift
//  MacRoot
//
//  Created by Алексей Трушковский on 27.01.2022.
//

import Cocoa
import AppKit
import Foundation
import SystemConfiguration

var oldIP: String?

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    internal var statusItem: NSStatusItem?
    internal var timer: Timer?
    private var authRef: AuthorizationRef?
    
    private let off = NSMenuItem(title: "Proxy Off", action: #selector(disableSocksProxy), keyEquivalent: "p")
    private let on = NSMenuItem(title: "Proxy On", action: #selector(enableSocksProxy), keyEquivalent: "o")
    
    @objc func enableSocksProxy() {
        on.state = .on
        off.state = .off
        socksVProxySet(enabled: true)
    }
    
    @objc func disableSocksProxy() {
        on.state = .off
        off.state = .on
        socksVProxySet(enabled: false)
    }
    
    private func socksVProxySet(enabled: Bool) {
        
        let prefRef = SCPreferencesCreateWithAuthorization(kCFAllocatorDefault, "systemProxySet" as CFString, nil, self.authRef)!
        let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)!
        
        var proxies = [NSObject: AnyObject]()
        
        // proxy enabled set
        if enabled {
            proxies[kCFNetworkProxiesSOCKSEnable] = 1 as NSNumber
            proxies[kCFNetworkProxiesSOCKSProxy] = UserDefaults.standard.string(forKey: "proxy_ip") as AnyObject?
            proxies[kCFNetworkProxiesSOCKSPort] = UserDefaults.standard.integer(forKey: "proxy_port") as NSNumber
//            proxies[kCFStreamPropertySOCKSUser] = UserDefaults.standard.string(forKey: "proxy_username") as AnyObject?
//            proxies[kCFStreamPropertySOCKSPassword] = UserDefaults.standard.string(forKey: "proxy_password") as AnyObject?
            proxies[kCFNetworkProxiesExcludeSimpleHostnames] = 1 as NSNumber
        } else {
            proxies[kCFNetworkProxiesSOCKSEnable] = 0 as NSNumber
        }
        
        sets.allKeys!.forEach { (key) in
            let dict = sets.object(forKey: key)!
            let hardware = (dict as AnyObject).value(forKeyPath: "Interface.Hardware")
            
            if hardware != nil && ["AirPort","Wi-Fi","Ethernet"].contains(hardware as! String) {
                SCPreferencesPathSetValue(prefRef, "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as CFString, proxies as CFDictionary)
            }
        }
        
        // commit to system preferences.
        let commitRet = SCPreferencesCommitChanges(prefRef)
        let applyRet = SCPreferencesApplyChanges(prefRef)
        SCPreferencesSynchronize(prefRef)
        
        Swift.print("after SCPreferencesCommitChanges: commitRet = \(commitRet), applyRet = \(applyRet)")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        authorize()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        
        let menu = NSMenu()
        menu.addItem(on)
        menu.addItem(off)
        off.state = .on
        menu.addItem(NSMenuItem.separator())

        var state: Int = 0
        if ( applicationIsInStartUpItems() ) {
            state = 1
        }

        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(AppDelegate.updateIPAddress), keyEquivalent: ""))

        let item:NSMenuItem = NSMenuItem(title: "Launch at startup", action: #selector(AppDelegate.toggleLaunchAtStartup), keyEquivalent: "")
        item.state = NSControl.StateValue(rawValue: state)
        menu.addItem(item)
        menu.addItem(NSMenuItem(title: "Quit MacRootVM", action: #selector(NSApplication.shared.terminate), keyEquivalent: "q"))
        statusItem!.menu = menu
        
        
        updateIPAddress()
        timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(AppDelegate.updateIPAddress), userInfo: nil, repeats: true)
        timer!.tolerance = 0.5
        NotificationCenter.default.addObserver(self, selector: #selector(self.enableSocksProxy), name: Notification.Name("OnProxy"), object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        timer = nil
        NSStatusBar.system.removeStatusItem(statusItem!)
        statusItem = nil
    }
    
    private func authorize(){
        let error = AuthorizationCreate(nil, nil, [], &authRef)
        assert(error == errAuthorizationSuccess)
    }
    
    func getPublicIP(completion: @escaping (String) -> ()) {
        
        let requestURL = NSURL(string: "https://api.myip.com")!
        var urlRequest = URLRequest(url: requestURL as URL)
        let session = URLSession.shared
        urlRequest.timeoutInterval = 1
        let task = session.dataTask(with: urlRequest) { (data, response, error) in
            if response == nil {
                completion("No Connection")
                return
            }
            let httpResponse = response as! HTTPURLResponse
            let statusCode = httpResponse.statusCode
            
            if (statusCode == 200) {
                if let data = data {
                    let stringData = String(data: data, encoding: .utf8)
                    completion(stringData?.components(separatedBy: "\"")[3] ?? "No Connection")
                }
            } else  {
                completion("No Connection")
            }
        }
        task.resume()
    }
    
    @objc func updateIPAddress() {
        getPublicIP(completion: { [self] currentIP in
            DispatchQueue.main.async {
                if currentIP != oldIP {
                    oldIP = currentIP
                    statusItem!.title = currentIP
                }
            }
        })
    }
    
    func applicationIsInStartUpItems() -> Bool {
        return (itemReferencesInLoginItems().existingReference != nil)
    }

    func itemReferencesInLoginItems() -> (existingReference: LSSharedFileListItem?, lastReference: LSSharedFileListItem?) {
        let appUrl : URL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            let loginItems = (LSSharedFileListCopySnapshot(loginItemsRef!, nil)?.takeRetainedValue()) as! NSArray
            if ( loginItems.count > 0 ) {
                let lastItemRef: LSSharedFileListItem = loginItems.lastObject as! LSSharedFileListItem
                for i in 0 ..< loginItems.count {
                    let currentItemRef: LSSharedFileListItem = loginItems.object(at: i) as! LSSharedFileListItem
                    if let urlRef: Unmanaged<CFURL> = LSSharedFileListItemCopyResolvedURL(currentItemRef, 0, nil) {
                        let urlRef:URL = urlRef.takeRetainedValue() as URL
                        if urlRef == appUrl {
                            return (currentItemRef, lastItemRef)
                        }
                    } else {
                        print("Unknown login application")
                    }
                }
                //The application was not found in the startup list
                return (nil, lastItemRef)
            } else {
                let addatstart: LSSharedFileListItem = kLSSharedFileListItemBeforeFirst.takeRetainedValue()
                return(nil,addatstart)
            }
        }

        return (nil, nil)
    }

    @objc func toggleLaunchAtStartup() {
        let itemReferences = itemReferencesInLoginItems()
        let shouldBeToggled = (itemReferences.existingReference == nil)
        let loginItemsRef = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() as LSSharedFileList?
        if loginItemsRef != nil {
            if shouldBeToggled {
                let appUrl = URL(fileURLWithPath: Bundle.main.bundlePath) as CFURL?
                if (nil != appUrl) {
                    LSSharedFileListInsertItemURL(
                        loginItemsRef!,
                        itemReferences.lastReference!,
                        nil,
                        nil,
                        appUrl!,
                        nil,
                        nil
                    )
                    print("Application was added to login items")
                }
            } else {
                if let itemRef = itemReferences.existingReference {
                    LSSharedFileListItemRemove(loginItemsRef!,itemRef)
                    print("Application was removed from login items")
                }
            }
        }
    }

}

