//
//  ViewController.swift
//  otkr
//
//  Created by Alexander Makhlin on 11/21/21.
//


import UIKit
import CoreBluetooth
import CoreLocation
//import os.log

class ViewController: UIViewController {
    
    var cnt: Int = 0
    var centralManager: CBCentralManager!
    var bluefruitPeripheral: CBPeripheral!
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    var tick: Bool = false
    var unlockComplete: Bool = false
    //var stopCmd: Bool = false

    let uuidService = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    let uuidCharacteristicTx = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
    let uuidCharacteristicRx = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var debugTextView: UITextView!
    @IBOutlet weak var labelVersion: UILabel!
    @IBOutlet weak var disconnectedLockImage: UIImageView!
    
    @IBOutlet weak var connectedLockImage: UIImageView!
    
    let geofenceRegionCenter = CLLocationCoordinate2DMake(41.95554389970018, -87.65005797692557)
    let radius: Double = 100
    var locationManager: CLLocationManager!
    
    var unlockingAllowed: Bool = false
    var locationInitialized: Bool = false
    var formatter = DateFormatter()
    //let logger = Logger.init(subsystem: "com.tradecraft.otkr", category: "main")
    
    func monitorRegionAtLocation(center: CLLocationCoordinate2D, identifier: String ) {
        // Make sure the devices supports region monitoring.
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            // Register the region.
            let region = CLCircularRegion(center: center,
                 radius: radius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = true
       
            locationManager.startMonitoring(for: region)
            locationManager.requestState(for: region)
            debug("location monitoring registred")
        }
        else{
            debug("location monitoring NOT available")
        }
    }
    
    func debug(_ str: String, addTimestamp: Bool = true){
        print(str)
        //logger.log("\(str, privacy: .public)")
        
        let timestampStr = (addTimestamp) ? " @ \(formatter.string(from: Date()))" : ""
        
        debugTextView.text! += str + timestampStr + "\n"
        let lastLine: NSRange = NSMakeRange(debugTextView.text.count - 1, 1)
        debugTextView.scrollRangeToVisible(lastLine)
    }
    
    
    @IBAction func UnlockButtonClicked(_ sender: Any) {
        connectToLock("-> ImmediateConnect", geofenceOverride: true)
    }
    
    func connectToLock(_ fromMsg: String, geofenceOverride: Bool){
        if(geofenceOverride || unlockingAllowed){
            // check to see if we've alrady discovered a peripheral previously
            if let bluefruitPeripheral = bluefruitPeripheral{
                if(bluefruitPeripheral.state != CBPeripheralState.connected){
                    centralManager?.connect(bluefruitPeripheral, options: nil)
                    debug("2. Connecting \(fromMsg)")
                }
                else{
                    debug("Already connected \(fromMsg)")
                    sendUlockCmd()
                }
            }
            else{
                startScanning()
                debug("Kicking off the scan \(fromMsg)")
            }

        }
        else{
            debug("2. Not Connecting because unlocking is not allowed")
        }
    }
    
    func sendUlockCmd(){
        let buffer: [UInt8] = [0x21, 0x42, 0x31, 0x31, 0x3A]
        let cmdStr = String(bytes: buffer, encoding: String.Encoding.ascii)
        
        writeOutgoingValue(data: cmdStr!)
        
        debug("6. Unlocking")
    }
    
    
    func disconnectFromLock(){
        if let bluefruitPeripheral = bluefruitPeripheral{
            centralManager?.cancelPeripheralConnection(bluefruitPeripheral)
            debug("Disconnected from Lock\n")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a d-MMM-y"
        
        debug("viewDidLoad")
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey: "bluelock"])
        locationManager = CLLocationManager()
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        monitorRegionAtLocation(center: geofenceRegionCenter, identifier: "4030ClarendonUnlockRegion")
        disconnectedLockImage.isHidden = false
        connectedLockImage.isHidden = true
        
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.labelVersion.text = "Ver. \(version)"
        }
    }
                                                                  

    

    func startScanning() -> Void {
        centralManager?.scanForPeripherals(withServices: [uuidService])//, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
        //centralManager?.scanForPeripherals(withServices: [] , options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        debug("\n1. Start Scanning")
    }
    
    func writeOutgoingValue(data: String){
        
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        
        if let bluefruitPeripheral = bluefruitPeripheral {
            if let txCharacteristic = txCharacteristic {
                bluefruitPeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
    
}

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOff:
            print("Is Powered Off.")
        case .poweredOn:
            //debug("Is Powered On.")
            debug("centralManagerDidUpdateState")
            disconnectFromLock()
            startScanning()
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
            print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
            print("Error")
        }
    }
    
    // this gets called after wakeup from background
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]){
        
        switch central.state {
        case .poweredOff:
            print("Is Powered Off.")
        case .poweredOn:
            print("Is Powered On.")
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
            print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
            print("Error")
        }
        
        debug("willRestoreState")
        
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            bluefruitPeripheral = peripherals[0]
            bluefruitPeripheral.delegate = self
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {
        bluefruitPeripheral = peripheral
        
        bluefruitPeripheral.delegate = self
        
        centralManager?.stopScan()
        
        // This is step 2
        connectToLock("didDiscover", geofenceOverride: false)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        bluefruitPeripheral.discoverServices([uuidService])
        //debug("3. Discovered Service: \(uuidService)")
        
        disconnectedLockImage.isHidden = true
        connectedLockImage.isHidden = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        startScanning()
        debug("Disconnect Detected")
        
        disconnectedLockImage.isHidden = false
        connectedLockImage.isHidden = true
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        startScanning()
        debug("Failed to Connect")
        
        disconnectedLockImage.isHidden = false
        connectedLockImage.isHidden = true
    }
}


extension ViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if ((error) != nil) {
            debug("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        //debug("4. Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        for characteristic in characteristics {
            
            if characteristic.uuid.isEqual(uuidCharacteristicRx)  {
                
                rxCharacteristic = characteristic
                
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
                
                //debug("5. Discovered RX Characteristic: \(rxCharacteristic.uuid)")
            }
            
            if characteristic.uuid.isEqual(uuidCharacteristicTx){
                
                txCharacteristic = characteristic
                
                //debug("5. Discovered TX Characteristic: \(txCharacteristic.uuid)")
                
                // kick off the unlock process
                sendUlockCmd()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic == rxCharacteristic,
              
                let characteristicValue = characteristic.value,
              let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { return }
        
        if(ASCIIstring.isEqual(to: "U")){
            
            debug("7. Confirmed Unlocking, Success!", addTimestamp: true)
            unlockComplete = true
            unlockingAllowed = false
        }
    }
}

extension ViewController: CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        debug("didEnterRegion")
        locationInitialized = true
        if(!unlockingAllowed){
            unlockingAllowed = true
            connectToLock("didEnterRegion", geofenceOverride: false);
        }

    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        debug("didExitRegion")
        locationInitialized = true
        if(!unlockingAllowed){
            unlockingAllowed = true
            connectToLock("didExitRegion", geofenceOverride: false);
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        debug("didDtermineState, locationInitialized is \(locationInitialized)")
        if(!locationInitialized){
            switch state {
            case .unknown:
                debug("didDetermineState unknown")
                unlockingAllowed = false
            case .inside:
                debug("didDetermineState inside")
                unlockingAllowed = false
            case .outside:
                debug("didDetermineState outside")
                if(!unlockingAllowed){
                    unlockingAllowed = true
                    //startScanning()
                    connectToLock("didDetermineState outside", geofenceOverride: false);
                    }
            }
            locationInitialized = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debug("Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard let region = region else {
          debug("Monitoring failed for unknown region")
          return
        }
        debug("Monitoring failed for region with identifier: \(region.identifier)")
    }
}
