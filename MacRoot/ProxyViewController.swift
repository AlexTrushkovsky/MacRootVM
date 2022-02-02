//
//  ProxyViewController.swift
//  MacRootVM
//
//  Created by Алексей Трушковский on 01.02.2022.
//

import Cocoa

class ProxyViewController: NSViewController {
    @IBOutlet weak var ipField: NSTextField!
    @IBOutlet weak var ipPort: NSTextField!
    @IBOutlet weak var usernameField: NSTextField!
    @IBOutlet weak var passwordField: NSTextField!
    
    @IBAction func ConfirmButton(_ sender: NSButton) {
        let ip = ipField.stringValue
        let port = ipPort.stringValue
//        let username = usernameField.stringValue
//        let password = passwordField.stringValue
        if !ip.isEmpty && !port.isEmpty {
            UserDefaults.standard.setValue(ip, forKey: "proxy_ip")
            UserDefaults.standard.setValue(port, forKey: "proxy_port")
            NotificationCenter.default.post(name: Notification.Name("OnProxy"), object: nil)
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Network.prefPane"))
//            UserDefaults.standard.setValue(username, forKey: "proxy_username")
//            UserDefaults.standard.setValue(password, forKey: "proxy_password")
            self.view.window?.windowController?.close()
            
        } else {
            showError(title: "Error", body: "Fill all the fields")
        }
    }
    
    func showError(title: String, body: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
}
