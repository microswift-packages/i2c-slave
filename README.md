# i2c Slave helpers

This gives basic slave I2C facilities, built on top of the standard I2C library.

For use if you want to create an I2C slave peripheral.

Note: timeout is the same intent as the main I2C library.


### Basic functions

We have slave send/receive functions based on buffers. Currently these are byte based. Unfortunately if you want to send or receive a buffer
of larger integers you'll need to manage that yourself.


#### RECEIVE DATA FROM MASTER
```
static func handleTwiSlaveReceiveEvent(
        buffer: UnsafeMutableBufferPointer<UInt8>,
        timeout: UInt16,
        callback: (UnsafeMutableBufferPointer<UInt8>, Int) -> Void) -> Bool
```
Call this to check if there are writes inbound FROM a master TO your slave. The function checks the TWI state before it does anything
and will exit immediately if the TWI circuitry via twsr does not indicate that there's inbound data.

The function will receive bytes one at a time, putting them into your buffer, returning ACK for each byte unless the buffer is full, in which
case it will return NACK to the last byte, storing it, and then it will call your callback passing the buffer, then exit.

If the function detects an unexpected status change after reading a byte, it will call the callback and exit. This means you can have a larger
buffer than the data you expect to receive sometimes, so it's safe to use a larger buffer to account for all possible cases.

*Footnote: Buffer management/memory*

You must pass it a buffer to store data received from the master in. You are responsible for managing that buffer lifetime, making sure it exists
and releasing it if needed. There is no automatic memory management! Note: in general it makes sense to keep one, fixed buffer at global scope to
store data in and reuse it. In this case, your callback should handle everything to do with the inbound data before it completes and should
assume that the buffer is no longer preserved after the callback is complete. It is usually not a good idea to allocate a new buffer for each
time you call this function, as that increases the risk of an out of memory bug.


#### SEND DATA TO MASTER

```
static func handleTwiSlaveTransmitEvent(
        timeout: UInt16,
        callback: () -> (buffer: UnsafeMutableBufferPointer<UInt8>, length: Int)) -> Bool
```
Call this to check if master wants to read FROM your slave. The function checks the TWI state before it does anything and will exit immediately
if the master has not requested data from YOUR slave.

You must provide a callback that returns a buffer of data to send to the master. When sending the buffer, the transmit function will ACK with
each byte it sends until the last byte of your buffer or until the length has been reached, when it will NACK.

Again, you are responsible for the lifetime management of the data buffer to send. It usually makes sense to keep one buffer at the top level
for the data you want to send and reuse it. Then fill that with data in your callback. To allow for one buffer to be reused, you send a length
of data to send.


### Recommendations for use

The recommended use is polling.

Interrupt driven is NOT better unless you have a specific low power requirement such as sleeping between handling i2c
 requests, in a very low power/sporadically used peripheral...
 interrupt driven is probably pointless complexity and risk unless saving 10mA power is very important.

If you must use interrupt driven then put the while loop code below into an I2C interrupt handler.


```
if let receiveBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(...)
// allocate and test allocation for slave receive buffer... stop the program with an error if it fails and is needed

if let sendBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(...)
// allocate and test allocation for slave send buffer... stop the program with an error if it fails and is needed

/// ...event handler loop...
while mainLoopRunning {
  if ATmega328P.Twi.waitForHardware(timeout: 50_000) {
    ATmega328P.Twi.handleTwiSlaveReceiveEvent(buffer: receiveBuffer, timeout: 50_000) {
      // handle slave buffer in $0, with byte count in $1
      // (the count will always be <= the buffer size... if the buffer gets filled, the function will NACK and not read any more bytes)
    }

    ATmega328P.Twi.handleTwiSlaveTransmitEvent(timeout: 50_000) {
      // return the buffer to transmit, you are responsible for lifetime and memory management of this buffer
      // usually the best pattern is keep one top level buffer, fill the contents on each call

      // if you need to return different sized buffers on each call, you might need to allocate and release on each
      // call, however be warned - DO NOT allocate and release heap buffers inside an interrupt handler!!
      // definitely consider switching to polling if you are using interrupt handling and you decide to follow this
      // pattern.... if you do not have anything running on the slave except the slave I2C interrupt handler then
      // it *might* be safe, as interrupts are non re-entrant and the main program won't be using the heap itself.
      // But in that case why not just move to polling and have the main loop handle it anyway? Aside from rare use/
      // low power niche cases, you're just adding pointless complexity and risk.

      return sendBuffer
    }
  }
}
```
