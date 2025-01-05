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
    var geofenceOverride = false;

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
            debug("ERROR: location monitoring NOT available")
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
        debug("-> ImmediateConnect: sending disconnectFromLock")
        disconnectFromLock()
        
        geofenceOverride = true;
        connectToLock()
    }
    
    func connectToLock(){
        if(geofenceOverride || unlockingAllowed){
            // check to see if we've alrady discovered a peripheral previously
            if let bluefruitPeripheral = bluefruitPeripheral{
                if(bluefruitPeripheral.state != CBPeripheralState.connected){
                    debug("2. Connecting")
                    centralManager?.connect(bluefruitPeripheral, options: nil)
                }
                else{
                    debug("connectToLock already connected so calling sendUlockCmd")
                    sendUlockCmd()
                }
            }
            else{
                debug("ERROR: onnectToLock peripheral is null, starting a scan")
                startScanning()
            }

        }
        else{
            debug("2. Connecting is not allowed\n", addTimestamp: false)
        }
    }
    
    func sendUlockCmd(){
        let buffer: [UInt8] = [0x21, 0x42, 0x31, 0x31, 0x3A]
        let cmdStr = String(bytes: buffer, encoding: String.Encoding.ascii)
        
        debug("6. Unlocking")

        writeOutgoingValue(data: cmdStr!)
    }
    
    
    func disconnectFromLock(){
        if let bluefruitPeripheral = bluefruitPeripheral{
            if(bluefruitPeripheral.state == CBPeripheralState.connected){
                debug("Disconnecting from Lock\n")
                centralManager?.cancelPeripheralConnection(bluefruitPeripheral)
            }
            else{
                debug("disconnectFromLock: already disconnected")
            }
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
        debug("\n1. Starting Scan")
        centralManager?.scanForPeripherals(withServices: [uuidService])//, options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])        
    }
    
    func writeOutgoingValue(data: String){
        
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        
        if let bluefruitPeripheral = bluefruitPeripheral {
            if let txCharacteristic = txCharacteristic {
                bluefruitPeripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
            else{
                debug("ERROR: writeOutgoingValue txChar does not match")
            }
        }
        else{
            debug("ERROR: writeOutgoingValue pripheral does not match")
        }
    }
    
}

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        switch central.state {
        case .poweredOff:
            debug("CBDidUpdateState: powered Off.")
        case .poweredOn:
            debug("CBDidUpdateState: powered on")
            disconnectFromLock()
            startScanning()
        case .unsupported:
            debug("CBDidUpdateState: unsupported.")
        case .unauthorized:
            debug("CBDidUpdateState: unauthorized.")
        case .unknown:
            debug("CBDidUpdateState: unknown")
        case .resetting:
            debug("CBDidUpdateState: resetting")
        @unknown default:
            debug("CBDidUpdateState: error")
        }
    }
    
    // this gets called after wakeup from background
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]){
        
        switch central.state {
        case .poweredOff:
            debug("CBwillRestoreState: powered Off.")
        case .poweredOn:
            debug("CBwillRestoreState: oowered On.")
        case .unsupported:
            debug("CBwillRestoreState: unsupported.")
        case .unauthorized:
            debug("CBwillRestoreState: unauthorized.")
        case .unknown:
            debug("CBwillRestoreState: unknown")
        case .resetting:
            debug("CBwillRestoreState: resetting")
        @unknown default:
            debug("CBwillRestoreState: error")
        }
        
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
        connectToLock()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debug("3. didConnect, discovering services")
        bluefruitPeripheral.discoverServices([uuidService])
        
        disconnectedLockImage.isHidden = true
        connectedLockImage.isHidden = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        debug("Disconnect Detected")
        startScanning()
        
        disconnectedLockImage.isHidden = false
        connectedLockImage.isHidden = true
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        debug("ERROR: Failed to Connect")
        startScanning()
        
        disconnectedLockImage.isHidden = false
        connectedLockImage.isHidden = true
    }
}


extension ViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        debug("4. Discovered Services")

        if ((error) != nil) {
            debug("ERROR: didDiscoverServices \(error!.localizedDescription)")
            disconnectFromLock()
            startScanning()
            return
        }
        guard let services = peripheral.services else {
            debug("ERROR: didDisconverServices peripheral.services is null")
            disconnectFromLock()
            startScanning()
            return
        }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        debug("5. Discovered Characteristics")
        guard let characteristics = service.characteristics else {
            debug("ERROR: didDiscoverCharacteristicsFor service.characteristics is null")
            disconnectFromLock()
            startScanning()
            return
        }
        
        for characteristic in characteristics {
            
            if characteristic.uuid.isEqual(uuidCharacteristicRx)  {
                rxCharacteristic = characteristic
                
                debug("5.1 set up callback for lock resp")
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
            }
            
            if characteristic.uuid.isEqual(uuidCharacteristicTx){
                txCharacteristic = characteristic
                debug("5.2 set tx char for writing to lock")
            
                // kick off the unlock process
                sendUlockCmd()
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic == rxCharacteristic,
            let characteristicValue = characteristic.value,
              let ASCIIstring = NSString(data: characteristicValue, encoding: String.Encoding.utf8.rawValue) else { 
                debug("ERROR: didUpdateValueFor can't get the value from rxCharacteristic")
                // this callback seems to fire twice, with the first call failing the guard conidtion above
                // so we can't give up and restart the process
                // instead webwait for the second callback which usually succeeds

                //disconnectFromLock()
                //startScanning()
                return 
              }
        
        if(ASCIIstring.isEqual(to: "U")){
            debug("7. Confirmed Unlocking, Success!", addTimestamp: true)
            unlockComplete = true
            unlockingAllowed = false
            geofenceOverride = false
            disconnectFromLock()
        }
        else{
            debug("ERROR: got wrong response from lock")
            disconnectFromLock()
            startScanning()
        }
    }
}

extension ViewController: CLLocationManagerDelegate{
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        //debug("didEnterRegion")
        locationInitialized = true
        if(!unlockingAllowed){
            unlockingAllowed = true
            debug("didEnterRegion: calling connectToLock")
            connectToLock();
        }

    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        //debug("didExitRegion")
        locationInitialized = true
        if(!unlockingAllowed){
            unlockingAllowed = true
            debug("didExitRegion: calling connectToLock")
            connectToLock();
        }
    }
    
    // this one is called on state transitions, so contemporenously with either of the two above
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        //debug("didDtermineState, locationInitialized is \(locationInitialized)")
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
                    debug("didDetermineState: calling connectToLock")
                    connectToLock();
                }
            }
            locationInitialized = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debug("ERROR: Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        guard let region = region else {
          debug("ERROR: Monitoring failed for unknown region")
          return
        }
        debug("ERROR: Monitoring failed for region with identifier: \(region.identifier)")
    }
}
