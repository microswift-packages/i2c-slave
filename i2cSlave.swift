import i2c
import HAL

public extension Twi where Twsr.RegisterType == UInt8 {
    /// typical use...
    /// In your slave program make the main loop this...
    /// let receiveBuffer = // allocate and test allocation for slave receive buffer
    /// ...event handler loop...
    /// while true {
    ///   if ATmega328P.Twi.waitForHardware(timeout: 50_000) {
    ///     ATmega328P.Twi.handleTwiSlaveReceiveEvent(buffer: receiveBuffer, timeout: 50_000) {
    ///      // handle slave buffer in $0, with byte count in $1
    ///      // (the count will always be <= the buffer size... if the buffer gets filled, the function will NACK and not read any more bytes)
    ///     }
    ///     ATmega328P.Twi.handleTwiSlaveTransmitEvent(timeout: 50_000) {
    ///       // return the buffer to transmit, you are responsible for lifetime and memory management of this buffer
    ///     }
    ///   }
    /// }
    
    @discardableResult
    static func handleTwiSlaveReceiveEvent(
        buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: UInt16,
        callback: (UnsafeMutableBufferPointer<UInt8>, Int) -> Void) -> Bool {

        // TWINT flag triggered, either polling or interrupt
        // first check status flag to see if we are being sent data (master wants to send us data)
        guard twsr.registerValue == 0x60 else { return false }
    
        var i: Int = 0

        defer {
            slaveRelease()
            callback(buffer, i)
        }

        while i < buffer.count {
            guard let c = read(sendAck: i<buffer.count-1, timeout: timeout) else { return false }
            guard twsr.registerValue == 0x80 || twsr.registerValue == 0x88 else { return false }
            buffer[i] = c
            i += 1
        }
    
        return true
    }

    @discardableResult
    static func handleTwiSlaveTransmitEvent(
        timeout: UInt16,
        callback: () -> (buffer: UnsafeMutableBufferPointer<UInt8>, length: Int)) -> Bool {

        // TWINT flag triggered, either polling or interrupt
        // first check status flag to see if we should send data (master asked us to send data)
        guard twsr.registerValue == 0xA8 else { return false }
    
        let callbackBufferAndLength = callback()
        let bufferToSend = callbackBufferAndLength.buffer
        let lengthToSend = min(callbackBufferAndLength.length,bufferToSend.count)

        defer {
            slaveRelease()
        }

        for i in 0..<lengthToSend {
            guard slaveWrite(byte: bufferToSend[i], sendAck: i<lengthToSend-1, timeout: timeout) else { return false }
            guard twsr.registerValue == 0xB8 else { return false }
        }

        return true
    }
}
