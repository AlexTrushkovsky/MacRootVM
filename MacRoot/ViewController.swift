//
//  ViewController.swift
//  MacRoot
//
//  Created by Алексей Трушковский on 27.01.2022.
//

import Cocoa
import IOKit

class ViewController: NSViewController {
    
    var vmPath = ""
    var models = ["MacBookPro16,4", "MacBookPro16,3", "MacBookPro16,2", "MacBookPro16,1", "MacBookPro15,4", "MacBookPro15,3", "MacBookPro15,2", "MacBookPro15,1", "MacBookAir9,1", "MacBookAir8,2", "MacBookAir8,1", "MacBook10,1", "MacPro7,1", "MacPro6,1", "iMac20,2", "iMac20,1", "iMac19,1", "iMacPro1,1", "Macmini8,1", "Macmini7,1"]
    
    @IBOutlet weak var ipIndicator: NSProgressIndicator!
    @IBOutlet weak var serialNumberField: NSTextField!
    @IBOutlet weak var UUIDField: NSTextField!
    @IBOutlet weak var MACAdressField: NSTextField!
    @IBOutlet weak var IPAddressField: NSTextField!
    @IBOutlet weak var vmNameLabel: NSTextField!
    @IBOutlet weak var modelField: NSTextField!
    
    @IBAction func selectVMAction(_ sender: NSButton) {
        let dialog = NSOpenPanel();
        
        dialog.title                   = "Choose Virtual Machine";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories    = false;
        dialog.allowedFileTypes        = ["vmwarevm"];
        
        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file
            if let result = result {
                let path: String = result.path
                let subs = try! FileManager.default.subpathsOfDirectory(atPath: path)
                let totalFiles = subs.count
                print(totalFiles)
                for sub in subs {
                    if sub.hasSuffix(".vmx") {
                        //a vmx
                        vmPath = "\(path)/\(String(sub.dropFirst().dropFirst()))"
                        vmNameLabel.stringValue = result.lastPathComponent
                        do {
                            let config = try String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
                            print(config)
                            print("Config Readed")
                            for line in config.lines {
                                if line.contains("hw.model =") {
                                    modelField.stringValue = line.components(separatedBy: "\"")[1]
                                }
                                if line.contains("serialNumber =") {
                                    serialNumberField.stringValue = line.components(separatedBy: "\"")[1]
                                }
                                if line.contains("uuid.bios =") {
                                    UUIDField.stringValue = line.components(separatedBy: "\"")[1].replacingOccurrences(of: " ", with: "")
                                }
                                if line.contains("ethernet0.address =") {
                                    MACAdressField.stringValue = line.components(separatedBy: "\"")[1]
                                }
                            }
                        } catch {
                            //Failed to read file
                        }
                        break
                    }
                }
            }
        } else {
            //User Cancelled
            return
        }
    }
    
    @IBAction func RefreshAction(_ sender: NSButton) {
        refreshData()
    }
    
    
    @IBAction func regenModelAction(_ sender: NSButton) {
        let newModel = models.randomElement()!
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return }
        var newConfig = config
        for line in config.lines {
            if line.contains("hw.model =") {
                let oldModel = line.components(separatedBy: "\"")[1]
                newConfig = newConfig.replacingOccurrences(of: oldModel, with: newModel)
                break
            }
        }
        if !newConfig.contains(newModel) {
            newConfig.append(contentsOf: "\nhw.model = \"\(newModel)\"")
        }
        do {
            try newConfig.write(to: URL(fileURLWithPath: vmPath), atomically: false, encoding: .utf8)
        } catch {
            showError(title: "Error", body: "Failed to save new Model")
        }
        refreshData()
    }
    
    @IBAction func regenSerialNumberAction(_ sender: NSButton) {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let newSerial = "CO2" + String((0..<9).map{ _ in letters.randomElement()! }).uppercased()
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return }
        var newConfig = config
        for line in config.lines {
            if line.contains("serialNumber =") {
                let oldSerial = line.components(separatedBy: "\"")[1]
                newConfig = newConfig.replacingOccurrences(of: oldSerial, with: newSerial)
                break
            }
        }
        if !newConfig.contains(newSerial) {
            newConfig.append(contentsOf: "\nserialNumber = \"\(newSerial)\"")
        }
        do {
            try newConfig.write(to: URL(fileURLWithPath: vmPath), atomically: false, encoding: .utf8)
        } catch {
            showError(title: "Error", body: "Failed to save new Serial Number")
        }
        refreshData()
    }
    
    @IBAction func regenUUIDAction(_ sender: NSButton) {
        var newUUID = shell("uuidgen").replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: " ", with: "").lowercased().replacingOccurrences(of: "\n", with: "")
        newUUID = String(newUUID.enumerated().map { $0 > 0 && $0 % 2 == 0 ? [" ", $1] : [$1]}.joined())
        newUUID.remove(at: newUUID.index(newUUID.startIndex, offsetBy: 23))
        newUUID.insert("-", at: newUUID.index(newUUID.startIndex, offsetBy: 23))
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return }
        var newConfig = config
        for line in config.lines {
            if line.contains("uuid.bios =") {
                let oldUUID = line.components(separatedBy: "\"")[1]
                newConfig = newConfig.replacingOccurrences(of: oldUUID, with: newUUID)
                break
            }
        }
        if !newConfig.contains(newUUID) {
            newConfig.append(contentsOf: "\nuuid.bios = \"\(newUUID)\"")
        }
        do {
            try newConfig.write(to: URL(fileURLWithPath: vmPath), atomically: false, encoding: .utf8)
        } catch {
            showError(title: "Error", body: "Failed to save new UUID")
        }
        refreshData()
    }
    
    @IBAction func regenMACAction(_ sender: NSButton) {
        let newMac = shell("od -An -N6 -tx1 /dev/urandom | sed -e 's/^  *//' -e 's/  */:/g' -e 's/:$//' -e 's/^\\(.\\)[13579bdf]/\\10/'").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "")
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return }
        var newConfig = config
        for line in config.lines {
            if line.contains("ethernet0.address =") {
                let oldMac = line.components(separatedBy: "\"")[1]
                newConfig = newConfig.replacingOccurrences(of: oldMac, with: newMac)
                break
            }
        }
        if !newConfig.contains(newMac) {
            newConfig.append(contentsOf: "\nethernet0.address = \"\(newMac)\"")
        }
        do {
            try newConfig.write(to: URL(fileURLWithPath: vmPath), atomically: false, encoding: .utf8)
        } catch {
            showError(title: "Error", body: "Failed to save new mac")
        }
        refreshData()
    }
    
    func shell(_ args: String) -> String {
        var outstr = ""
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", args]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            outstr = output as String
        }
        task.waitUntilExit()
        return outstr
    }
    
    var model: String? {
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return nil }
        for line in config.lines {
            if line.contains("hw.model =") {
                return line.components(separatedBy: "\"")[1]
            }
            
        }
        return nil
    }
    
    var serialNumber: String? {
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return nil }
        for line in config.lines {
            if line.contains("serialNumber =") {
                return line.components(separatedBy: "\"")[1]
            }
            
        }
        return nil
    }
    
    var UUIDNumber: String? {
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return nil }
        for line in config.lines {
            if line.contains("uuid.bios =") {
                return line.components(separatedBy: "\"")[1].replacingOccurrences(of: " ", with: "")
            }
        }
        return nil
    }
    
    var MACaddress: String? {
        let config = try? String(contentsOf: URL(fileURLWithPath: vmPath), encoding: .utf8)
        guard let config = config else { return nil }
        for line in config.lines {
            if line.contains("ethernet0.address =") {
                return line.components(separatedBy: "\"")[1]
            }
        }
        return nil
    }
    
    func getPublicIPAddress(completion: @escaping (String?) -> ()) {
        ipIndicator.startAnimation(nil)
        let urlSession = URLSession(configuration: .ephemeral)
        guard let url = URL(string: "https://api.ipify.org/") else { return completion(nil) }
        urlSession.dataTask(with: URLRequest(url: url)) { data, response, error in
            guard let data = data else { return }
            let ip = String(data: data, encoding: .utf8)
            completion(ip)
        }.resume()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        modelField.isEditable = false
        UUIDField.isEditable = false
        MACAdressField.isEditable = false
        serialNumberField.isEditable = false
        IPAddressField.isEditable = false
        refreshData(load: true)
    }
    
    func refreshData(load: Bool = false) {
        getPublicIPAddress { ip in
            DispatchQueue.main.async {
                self.IPAddressField.stringValue = ip ?? "Undefined"
                self.ipIndicator.stopAnimation(nil)
            }
        }
        if vmPath.isEmpty && !load {
            showError(title: "Select VM", body: "Select file with .vmwarevm extension")
            return
        }
        
        modelField.stringValue = model ?? "Undefined"
        UUIDField.stringValue = UUIDNumber ?? "Undefined"
        serialNumberField.stringValue = serialNumber ?? "Undefined"
        MACAdressField.stringValue = MACaddress ?? "Undefined"
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

extension String {
    var lines: [String] {
        return self.components(separatedBy: "\n")
    }
}
