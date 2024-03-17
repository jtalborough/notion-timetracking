    import IOKit.hid

func getIdleTime() -> Int? {
    var idleTimeInt64 = Int64(0)
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
    
    if service != 0 {
        defer { IOObjectRelease(service) }
        
        guard let unmanagedDict = IORegistryEntryCreateCFProperty(service, kIOHIDIdleTimeKey as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        defer { unmanagedDict.release() }
        
        let idleTimeNumber: CFNumber = unmanagedDict.takeRetainedValue() as! CFNumber
        if !CFNumberGetValue(idleTimeNumber, CFNumberType.sInt64Type, &idleTimeInt64) {
            print("Error retrieving idle time")
            return nil
        }
        
        // Convert nanoseconds to seconds and then to Int
        let idleTimeInSeconds = Int(idleTimeInt64 / 1_000_000_000)
        return idleTimeInSeconds
    } else {
        print("IOServiceGetMatchingService failed")
        return nil
    }
}
