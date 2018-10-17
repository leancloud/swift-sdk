//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Websocket.swift
//
//  Created by Dalton Cherry on 7/16/14.
//  Copyright (c) 2014-2017 Dalton Cherry.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import CoreFoundation
import CommonCrypto

let WebsocketDidConnectNotification = "WebsocketDidConnectNotification"
let WebsocketDidDisconnectNotification = "WebsocketDidDisconnectNotification"
let WebsocketDisconnectionErrorKeyName = "WebsocketDisconnectionErrorKeyName"

//Standard WebSocket close codes
enum CloseCode : UInt16 {
    case normal                 = 1000
    case goingAway              = 1001
    case protocolError          = 1002
    case protocolUnhandledType  = 1003
    // 1004 reserved.
    case noStatusReceived       = 1005
    //1006 reserved.
    case encoding               = 1007
    case policyViolated         = 1008
    case messageTooBig          = 1009
}

enum ErrorType: Error {
    case outputStreamWriteError //output stream error during write
    case compressionError
    case invalidSSLError //Invalid SSL certificate
    case writeTimeoutError //The socket timed out waiting to be ready to write
    case protocolError //There was an error parsing the WebSocket frames
    case upgradeError //There was an error during the HTTP upgrade
    case closeError //There was an error during the close (socket probably has been dereferenced)
}

struct WSError: Error {
    let type: ErrorType
    let message: String
    let code: Int
}

//WebSocketClient is setup to be dependency injection for testing
protocol WebSocketClient: class {
    var delegate: WebSocketDelegate? {get set}
    var pongDelegate: WebSocketPongDelegate? {get set}
    var disableSSLCertValidation: Bool {get set}
    var overrideTrustHostname: Bool {get set}
    var desiredTrustHostname: String? {get set}
    var sslClientCertificate: SSLClientCertificate? {get set}
    #if os(Linux)
    #else
    var security: SSLTrustValidator? {get set}
    var enabledSSLCipherSuites: [SSLCipherSuite]? {get set}
    #endif
    var isConnected: Bool {get}
    
    func connect()
    func disconnect(forceTimeout: TimeInterval?, closeCode: UInt16)
    func write(string: String, completion: (() -> ())?)
    func write(data: Data, completion: (() -> ())?)
    func write(ping: Data, completion: (() -> ())?)
    func write(pong: Data, completion: (() -> ())?)
}

//implements some of the base behaviors
extension WebSocketClient {
    func write(string: String) {
        write(string: string, completion: nil)
    }
    
    func write(data: Data) {
        write(data: data, completion: nil)
    }
    
    func write(ping: Data) {
        write(ping: ping, completion: nil)
    }

    func write(pong: Data) {
        write(pong: pong, completion: nil)
    }
    
    func disconnect() {
        disconnect(forceTimeout: nil, closeCode: CloseCode.normal.rawValue)
    }
}

//SSL settings for the stream
struct SSLSettings {
    let useSSL: Bool
    let disableCertValidation: Bool
    var overrideTrustHostname: Bool
    var desiredTrustHostname: String?
    let sslClientCertificate: SSLClientCertificate?
    #if os(Linux)
    #else
    let cipherSuites: [SSLCipherSuite]?
    #endif
}

protocol WSStreamDelegate: class {
    func newBytesInStream()
    func streamDidError(error: Error?)
}

//This protocol is to allow custom implemention of the underlining stream. This way custom socket libraries (e.g. linux) can be used
protocol WSStream {
    var delegate: WSStreamDelegate? {get set}
    func connect(url: URL, port: Int, timeout: TimeInterval, ssl: SSLSettings, completion: @escaping ((Error?) -> Void))
    func write(data: Data) -> Int
    func read() -> Data?
    func cleanup()
    #if os(Linux) || os(watchOS)
    #else
    func sslTrust() -> (trust: SecTrust?, domain: String?)
    #endif
}

class FoundationStream : NSObject, WSStream, StreamDelegate  {
    private static let sharedWorkQueue = DispatchQueue(label: "com.vluxe.starscream.websocket", attributes: [])
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    weak var delegate: WSStreamDelegate?
    let BUFFER_MAX = 4096
	
	var enableSOCKSProxy = false
    
    func connect(url: URL, port: Int, timeout: TimeInterval, ssl: SSLSettings, completion: @escaping ((Error?) -> Void)) {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        let h = url.host! as NSString
        CFStreamCreatePairWithSocketToHost(nil, h, UInt32(port), &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()

        #if os(watchOS) //watchOS us unfortunately is missing the kCFStream properties to make this work
        #else
            if enableSOCKSProxy {
                let proxyDict = CFNetworkCopySystemProxySettings()
                let socksConfig = CFDictionaryCreateMutableCopy(nil, 0, proxyDict!.takeRetainedValue())
                let propertyKey = CFStreamPropertyKey(rawValue: kCFStreamPropertySOCKSProxy)
                CFWriteStreamSetProperty(outputStream, propertyKey, socksConfig)
                CFReadStreamSetProperty(inputStream, propertyKey, socksConfig)
            }
        #endif
        
        guard let inStream = inputStream, let outStream = outputStream else { return }
        inStream.delegate = self
        outStream.delegate = self
        if ssl.useSSL {
            inStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL as AnyObject, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            outStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL as AnyObject, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            #if os(watchOS) //watchOS us unfortunately is missing the kCFStream properties to make this work
            #else
                var settings = [NSObject: NSObject]()
                if ssl.disableCertValidation {
                    settings[kCFStreamSSLValidatesCertificateChain] = NSNumber(value: false)
                }
                if ssl.overrideTrustHostname {
                    if let hostname = ssl.desiredTrustHostname {
                        settings[kCFStreamSSLPeerName] = hostname as NSString
                    } else {
                        settings[kCFStreamSSLPeerName] = kCFNull
                    }
                }
                if let sslClientCertificate = ssl.sslClientCertificate {
                    settings[kCFStreamSSLCertificates] = sslClientCertificate.streamSSLCertificates
                }
                
                inStream.setProperty(settings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
                outStream.setProperty(settings, forKey: kCFStreamPropertySSLSettings as Stream.PropertyKey)
            #endif

            #if os(Linux)
            #else
            if let cipherSuites = ssl.cipherSuites {
                #if os(watchOS) //watchOS us unfortunately is missing the kCFStream properties to make this work
                #else
                if let sslContextIn = CFReadStreamCopyProperty(inputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext?,
                    let sslContextOut = CFWriteStreamCopyProperty(outputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext? {
                    let resIn = SSLSetEnabledCiphers(sslContextIn, cipherSuites, cipherSuites.count)
                    let resOut = SSLSetEnabledCiphers(sslContextOut, cipherSuites, cipherSuites.count)
                    if resIn != errSecSuccess {
                        completion(WSError(type: .invalidSSLError, message: "Error setting ingoing cypher suites", code: Int(resIn)))
                    }
                    if resOut != errSecSuccess {
                        completion(WSError(type: .invalidSSLError, message: "Error setting outgoing cypher suites", code: Int(resOut)))
                    }
                }
                #endif
            }
            #endif
        }
        
        CFReadStreamSetDispatchQueue(inStream, FoundationStream.sharedWorkQueue)
        CFWriteStreamSetDispatchQueue(outStream, FoundationStream.sharedWorkQueue)
        inStream.open()
        outStream.open()
        
        var out = timeout// wait X seconds before giving up
        FoundationStream.sharedWorkQueue.async { [weak self] in
            while !outStream.hasSpaceAvailable {
                usleep(100) // wait until the socket is ready
                out -= 100
                if out < 0 {
                    completion(WSError(type: .writeTimeoutError, message: "Timed out waiting for the socket to be ready for a write", code: 0))
                    return
                } else if let error = outStream.streamError {
                    completion(error)
                    return // disconnectStream will be called.
                } else if self == nil {
                    completion(WSError(type: .closeError, message: "socket object has been dereferenced", code: 0))
                    return
                }
            }
            completion(nil) //success!
        }
    }
    
    func write(data: Data) -> Int {
        guard let outStream = outputStream else {return -1}
        let buffer = UnsafeRawPointer((data as NSData).bytes).assumingMemoryBound(to: UInt8.self)
        return outStream.write(buffer, maxLength: data.count)
    }
    
    func read() -> Data? {
        guard let stream = inputStream else {return nil}
        let buf = NSMutableData(capacity: BUFFER_MAX)
        let buffer = UnsafeMutableRawPointer(mutating: buf!.bytes).assumingMemoryBound(to: UInt8.self)
        let length = stream.read(buffer, maxLength: BUFFER_MAX)
        if length < 1 {
            return nil
        }
        return Data(bytes: buffer, count: length)
    }
    
    func cleanup() {
        if let stream = inputStream {
            stream.delegate = nil
            CFReadStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        if let stream = outputStream {
            stream.delegate = nil
            CFWriteStreamSetDispatchQueue(stream, nil)
            stream.close()
        }
        outputStream = nil
        inputStream = nil
    }
    
    #if os(Linux) || os(watchOS)
    #else
    func sslTrust() -> (trust: SecTrust?, domain: String?) {
        guard let outputStream = outputStream else { return (nil, nil) }

        let trust = outputStream.property(forKey: kCFStreamPropertySSLPeerTrust as Stream.PropertyKey) as! SecTrust?
        var domain = outputStream.property(forKey: kCFStreamSSLPeerName as Stream.PropertyKey) as! String?
        if domain == nil,
            let sslContextOut = CFWriteStreamCopyProperty(outputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext? {
            var peerNameLen: Int = 0
            SSLGetPeerDomainNameLength(sslContextOut, &peerNameLen)
            var peerName = Data(count: peerNameLen)
            let _ = peerName.withUnsafeMutableBytes { (peerNamePtr: UnsafeMutablePointer<Int8>) in
                SSLGetPeerDomainName(sslContextOut, peerNamePtr, &peerNameLen)
            }
            if let peerDomain = String(bytes: peerName, encoding: .utf8), peerDomain.count > 0 {
                domain = peerDomain
            }
        }
        
        return (trust, domain)
    }
    #endif
    
    /**
     Delegate for the stream methods. Processes incoming bytes
     */
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if eventCode == .hasBytesAvailable {
            if aStream == inputStream {
                delegate?.newBytesInStream()
            }
        } else if eventCode == .errorOccurred {
            delegate?.streamDidError(error: aStream.streamError)
        } else if eventCode == .endEncountered {
            delegate?.streamDidError(error: nil)
        }
    }
}

//WebSocket implementation

//standard delegate you should use
protocol WebSocketDelegate: class {
    func websocketDidConnect(socket: WebSocketClient)
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?)
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String)
    func websocketDidReceiveData(socket: WebSocketClient, data: Data)
}

//got pongs
protocol WebSocketPongDelegate: class {
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?)
}

// A Delegate with more advanced info on messages and connection etc.
protocol WebSocketAdvancedDelegate: class {
    func websocketDidConnect(socket: WebSocket)
    func websocketDidDisconnect(socket: WebSocket, error: Error?)
    func websocketDidReceiveMessage(socket: WebSocket, text: String, response: WebSocket.WSResponse)
    func websocketDidReceiveData(socket: WebSocket, data: Data, response: WebSocket.WSResponse)
    func websocketHttpUpgrade(socket: WebSocket, request: String)
    func websocketHttpUpgrade(socket: WebSocket, response: String)
}


class WebSocket : NSObject, StreamDelegate, WebSocketClient, WSStreamDelegate {

    enum OpCode : UInt8 {
        case continueFrame = 0x0
        case textFrame = 0x1
        case binaryFrame = 0x2
        // 3-7 are reserved.
        case connectionClose = 0x8
        case ping = 0x9
        case pong = 0xA
        // B-F reserved.
    }

    static let ErrorDomain = "WebSocket"

    // Where the callback is executed. It defaults to the main UI thread queue.
    var callbackQueue = DispatchQueue.main

    // MARK: - Constants

    let headerWSUpgradeName     = "Upgrade"
    let headerWSUpgradeValue    = "websocket"
    let headerWSHostName        = "Host"
    let headerWSConnectionName  = "Connection"
    let headerWSConnectionValue = "Upgrade"
    let headerWSProtocolName    = "Sec-WebSocket-Protocol"
    let headerWSVersionName     = "Sec-WebSocket-Version"
    let headerWSVersionValue    = "13"
    let headerWSExtensionName   = "Sec-WebSocket-Extensions"
    let headerWSKeyName         = "Sec-WebSocket-Key"
    let headerOriginName        = "Origin"
    let headerWSAcceptName      = "Sec-WebSocket-Accept"
    let BUFFER_MAX              = 4096
    let FinMask: UInt8          = 0x80
    let OpCodeMask: UInt8       = 0x0F
    let RSVMask: UInt8          = 0x70
    let RSV1Mask: UInt8         = 0x40
    let MaskMask: UInt8         = 0x80
    let PayloadLenMask: UInt8   = 0x7F
    let MaxFrameSize: Int       = 32
    let httpSwitchProtocolCode  = 101
    let supportedSSLSchemes     = ["wss", "https"]

    class WSResponse {
        var isFin = false
        var code: OpCode = .continueFrame
        var bytesLeft = 0
        var frameCount = 0
        var buffer: NSMutableData?
        let firstFrame = {
            return Date()
        }()
    }

    // MARK: - Delegates

    /// Responds to callback about new messages coming in over the WebSocket
    /// and also connection/disconnect messages.
    weak var delegate: WebSocketDelegate?
    
    /// The optional advanced delegate can be used instead of of the delegate
    weak var advancedDelegate: WebSocketAdvancedDelegate?

    /// Receives a callback for each pong message recived.
    weak var pongDelegate: WebSocketPongDelegate?
    
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
    var onData: ((Data) -> Void)?
    var onPong: ((Data?) -> Void)?
    var onHttpResponseHeaders: (([String: String]) -> Void)?

    var disableSSLCertValidation = false
    var overrideTrustHostname = false
    var desiredTrustHostname: String? = nil
    var sslClientCertificate: SSLClientCertificate? = nil

    var enableCompression = true
    #if os(Linux)
    #else
    var security: SSLTrustValidator?
    var enabledSSLCipherSuites: [SSLCipherSuite]?
    #endif
    
    var isConnected: Bool {
        mutex.lock()
        let isConnected = connected
        mutex.unlock()
        return isConnected
    }
    var request: URLRequest //this is only to allow headers, timeout, etc to be modified on reconnect
    var currentURL: URL { return request.url! }

    var respondToPingWithPong: Bool = true

    // MARK: - Private

    private struct CompressionState {
        var supportsCompression = false
        var messageNeedsDecompression = false
        var serverMaxWindowBits = 15
        var clientMaxWindowBits = 15
        var clientNoContextTakeover = false
        var serverNoContextTakeover = false
        var decompressor:Decompressor? = nil
        var compressor:Compressor? = nil
    }
    
    private var stream: WSStream
    private var connected = false
    private var isConnecting = false
    private let mutex = NSLock()
    private var compressionState = CompressionState()
    private var writeQueue = OperationQueue()
    private var readStack = [WSResponse]()
    private var inputQueue = [Data]()
    private var fragBuffer: Data?
    private var certValidated = false
    private var didDisconnect = false
    private var readyToWrite = false
    private var headerSecKey = ""
    private var canDispatch: Bool {
        mutex.lock()
        let canWork = readyToWrite
        mutex.unlock()
        return canWork
    }
    
    /// Used for setting protocols.
    init(request: URLRequest, protocols: [String]? = nil, stream: WSStream = FoundationStream()) {
        self.request = request
        self.stream = stream
        if request.value(forHTTPHeaderField: headerOriginName) == nil {
            guard let url = request.url else {return}
            var origin = url.absoluteString
            if let hostUrl = URL (string: "/", relativeTo: url) {
                origin = hostUrl.absoluteString
                origin.remove(at: origin.index(before: origin.endIndex))
            }
            self.request.setValue(origin, forHTTPHeaderField: headerOriginName)
        }
        if let protocols = protocols {
            self.request.setValue(protocols.joined(separator: ","), forHTTPHeaderField: headerWSProtocolName)
        }
        writeQueue.maxConcurrentOperationCount = 1
    }
    
    convenience init(url: URL, protocols: [String]? = nil) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        self.init(request: request, protocols: protocols)
    }

    // Used for specifically setting the QOS for the write queue.
    convenience init(url: URL, writeQueueQOS: QualityOfService, protocols: [String]? = nil) {
        self.init(url: url, protocols: protocols)
        writeQueue.qualityOfService = writeQueueQOS
    }

    /**
     Connect to the WebSocket server on a background thread.
     */
    func connect() {
        guard !isConnecting else { return }
        didDisconnect = false
        isConnecting = true
        createHTTPRequest()
    }

    /**
     Disconnect from the server. I send a Close control frame to the server, then expect the server to respond with a Close control frame and close the socket from its end. I notify my delegate once the socket has been closed.

     If you supply a non-nil `forceTimeout`, I wait at most that long (in seconds) for the server to close the socket. After the timeout expires, I close the socket and notify my delegate.

     If you supply a zero (or negative) `forceTimeout`, I immediately close the socket (without sending a Close control frame) and notify my delegate.

     - Parameter forceTimeout: Maximum time to wait for the server to close the socket.
     - Parameter closeCode: The code to send on disconnect. The default is the normal close code for cleanly disconnecting a webSocket.
    */
    func disconnect(forceTimeout: TimeInterval? = nil, closeCode: UInt16 = CloseCode.normal.rawValue) {
        guard isConnected else { return }
        switch forceTimeout {
        case .some(let seconds) where seconds > 0:
            let milliseconds = Int(seconds * 1_000)
            callbackQueue.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { [weak self] in
                self?.disconnectStream(nil)
            }
            fallthrough
        case .none:
            writeError(closeCode)
        default:
            disconnectStream(nil)
            break
        }
    }

    /**
     Write a string to the websocket. This sends it as a text frame.

     If you supply a non-nil completion block, I will perform it when the write completes.

     - parameter string:        The string to write.
     - parameter completion: The (optional) completion handler.
     */
    func write(string: String, completion: (() -> ())? = nil) {
        guard isConnected else { return }
        dequeueWrite(string.data(using: String.Encoding.utf8)!, code: .textFrame, writeCompletion: completion)
    }

    /**
     Write binary data to the websocket. This sends it as a binary frame.

     If you supply a non-nil completion block, I will perform it when the write completes.

     - parameter data:       The data to write.
     - parameter completion: The (optional) completion handler.
     */
    func write(data: Data, completion: (() -> ())? = nil) {
        guard isConnected else { return }
        dequeueWrite(data, code: .binaryFrame, writeCompletion: completion)
    }

    /**
     Write a ping to the websocket. This sends it as a control frame.
     Yodel a   sound  to the planet.    This sends it as an astroid. http://youtu.be/Eu5ZJELRiJ8?t=42s
     */
    func write(ping: Data, completion: (() -> ())? = nil) {
        guard isConnected else { return }
        dequeueWrite(ping, code: .ping, writeCompletion: completion)
    }

    /**
     Write a pong to the websocket. This sends it as a control frame.
     Respond to a Yodel.
     */
    func write(pong: Data, completion: (() -> ())? = nil) {
        guard isConnected else { return }
        dequeueWrite(pong, code: .pong, writeCompletion: completion)
    }

    /**
     Private method that starts the connection.
     */
    private func createHTTPRequest() {
        guard let url = request.url else {return}
        var port = url.port
        if port == nil {
            if supportedSSLSchemes.contains(url.scheme!) {
                port = 443
            } else {
                port = 80
            }
        }
        request.setValue(headerWSUpgradeValue, forHTTPHeaderField: headerWSUpgradeName)
        request.setValue(headerWSConnectionValue, forHTTPHeaderField: headerWSConnectionName)
        headerSecKey = generateWebSocketKey()
        request.setValue(headerWSVersionValue, forHTTPHeaderField: headerWSVersionName)
        request.setValue(headerSecKey, forHTTPHeaderField: headerWSKeyName)
        
        if enableCompression {
            let val = "permessage-deflate; client_max_window_bits; server_max_window_bits=15"
            request.setValue(val, forHTTPHeaderField: headerWSExtensionName)
        }
        let hostValue = request.allHTTPHeaderFields?[headerWSHostName] ?? "\(url.host!):\(port!)"
        request.setValue(hostValue, forHTTPHeaderField: headerWSHostName)

        var path = url.absoluteString
        let offset = (url.scheme?.count ?? 2) + 3
        path = String(path[path.index(path.startIndex, offsetBy: offset)..<path.endIndex])
        if let range = path.range(of: "/") {
            path = String(path[range.lowerBound..<path.endIndex])
        } else {
            path = "/"
            if let query = url.query {
                path += "?" + query
            }
        }
        
        var httpBody = "\(request.httpMethod ?? "GET") \(path) HTTP/1.1\r\n"
        if let headers = request.allHTTPHeaderFields {
            for (key, val) in headers {
                httpBody += "\(key): \(val)\r\n"
            }
        }
        httpBody += "\r\n"
        
        initStreamsWithData(httpBody.data(using: .utf8)!, Int(port!))
        advancedDelegate?.websocketHttpUpgrade(socket: self, request: httpBody)
    }

    /**
     Generate a WebSocket key as needed in RFC.
     */
    private func generateWebSocketKey() -> String {
        var key = ""
        let seed = 16
        for _ in 0..<seed {
            let uni = UnicodeScalar(UInt32(97 + arc4random_uniform(25)))
            key += "\(Character(uni!))"
        }
        let data = key.data(using: String.Encoding.utf8)
        let baseKey = data?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        return baseKey!
    }

    /**
     Start the stream connection and write the data to the output stream.
     */
    private func initStreamsWithData(_ data: Data, _ port: Int) {

        guard let url = request.url else {
            disconnectStream(nil, runDelegate: true)
            return
            
        }
        // Disconnect and clean up any existing streams before setting up a new pair
        disconnectStream(nil, runDelegate: false)

        let useSSL = supportedSSLSchemes.contains(url.scheme!)
        #if os(Linux)
            let settings = SSLSettings(useSSL: useSSL,
                                       disableCertValidation: disableSSLCertValidation,
                                       overrideTrustHostname: overrideTrustHostname,
                                       desiredTrustHostname: desiredTrustHostname),
                                       sslClientCertificate: sslClientCertificate
        #else
            let settings = SSLSettings(useSSL: useSSL,
                                       disableCertValidation: disableSSLCertValidation,
                                       overrideTrustHostname: overrideTrustHostname,
                                       desiredTrustHostname: desiredTrustHostname,
                                       sslClientCertificate: sslClientCertificate,
                                       cipherSuites: self.enabledSSLCipherSuites)
        #endif
        certValidated = !useSSL
        let timeout = request.timeoutInterval * 1_000_000
        stream.delegate = self
        stream.connect(url: url, port: port, timeout: timeout, ssl: settings, completion: { [weak self] (error) in
            guard let self = self else {return}
            if error != nil {
                self.disconnectStream(error)
                return
            }
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak self, weak operation] in
                guard let sOperation = operation, let self = self else { return }
                guard !sOperation.isCancelled else { return }
                // Do the pinning now if needed
                #if os(Linux) || os(watchOS)
                    self.certValidated = false
                #else
                    if let sec = self.security, !self.certValidated {
                        let trustObj = self.stream.sslTrust()
                        if let possibleTrust = trustObj.trust {
                            self.certValidated = sec.isValid(possibleTrust, domain: trustObj.domain)
                        } else {
                            self.certValidated = false
                        }
                        if !self.certValidated {
                            self.disconnectStream(WSError(type: .invalidSSLError, message: "Invalid SSL certificate", code: 0))
                            return
                        }
                    }
                #endif
                let _ = self.stream.write(data: data)
            }
            self.writeQueue.addOperation(operation)
        })

        self.mutex.lock()
        self.readyToWrite = true
        self.mutex.unlock()
    }

    /**
     Delegate for the stream methods. Processes incoming bytes
     */
    
    func newBytesInStream() {
        processInputStream()
    }
    
    func streamDidError(error: Error?) {
        disconnectStream(error)
    }

    /**
     Disconnect the stream object and notifies the delegate.
     */
    private func disconnectStream(_ error: Error?, runDelegate: Bool = true) {
        if error == nil {
            writeQueue.waitUntilAllOperationsAreFinished()
        } else {
            writeQueue.cancelAllOperations()
        }
        
        mutex.lock()
        cleanupStream()
        connected = false
        mutex.unlock()
        if runDelegate {
            doDisconnect(error)
        }
    }

    /**
     cleanup the streams.
     */
    private func cleanupStream() {
        stream.cleanup()
        fragBuffer = nil
    }

    /**
     Handles the incoming bytes and sending them to the proper processing method.
     */
    private func processInputStream() {
        let data = stream.read()
        guard let d = data else { return }
        var process = false
        if inputQueue.count == 0 {
            process = true
        }
        inputQueue.append(d)
        if process {
            dequeueInput()
        }
    }

    /**
     Dequeue the incoming input so it is processed in order.
     */
    private func dequeueInput() {
        while !inputQueue.isEmpty {
            autoreleasepool {
                let data = inputQueue[0]
                var work = data
                if let buffer = fragBuffer {
                    var combine = NSData(data: buffer) as Data
                    combine.append(data)
                    work = combine
                    fragBuffer = nil
                }
                let buffer = UnsafeRawPointer((work as NSData).bytes).assumingMemoryBound(to: UInt8.self)
                let length = work.count
                if !connected {
                    processTCPHandshake(buffer, bufferLen: length)
                } else {
                    processRawMessagesInBuffer(buffer, bufferLen: length)
                }
                inputQueue = inputQueue.filter{ $0 != data }
            }
        }
    }

    /**
     Handle checking the inital connection status
     */
    private func processTCPHandshake(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) {
        let code = processHTTP(buffer, bufferLen: bufferLen)
        switch code {
        case 0:
            break
        case -1:
            fragBuffer = Data(bytes: buffer, count: bufferLen)
            break // do nothing, we are going to collect more data
        default:
            doDisconnect(WSError(type: .upgradeError, message: "Invalid HTTP upgrade", code: code))
        }
    }

    /**
     Finds the HTTP Packet in the TCP stream, by looking for the CRLF.
     */
    private func processHTTP(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) -> Int {
        let CRLFBytes = [UInt8(ascii: "\r"), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\n")]
        var k = 0
        var totalSize = 0
        for i in 0..<bufferLen {
            if buffer[i] == CRLFBytes[k] {
                k += 1
                if k == 4 {
                    totalSize = i + 1
                    break
                }
            } else {
                k = 0
            }
        }
        if totalSize > 0 {
            let code = validateResponse(buffer, bufferLen: totalSize)
            if code != 0 {
                return code
            }
            isConnecting = false
            mutex.lock()
            connected = true
            mutex.unlock()
            didDisconnect = false
            if canDispatch {
                callbackQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.onConnect?()
                    self.delegate?.websocketDidConnect(socket: self)
                    self.advancedDelegate?.websocketDidConnect(socket: self)
                    NotificationCenter.default.post(name: NSNotification.Name(WebsocketDidConnectNotification), object: self)
                }
            }
            //totalSize += 1 //skip the last \n
            let restSize = bufferLen - totalSize
            if restSize > 0 {
                processRawMessagesInBuffer(buffer + totalSize, bufferLen: restSize)
            }
            return 0 //success
        }
        return -1 // Was unable to find the full TCP header.
    }

    /**
     Validates the HTTP is a 101 as per the RFC spec.
     */
    private func validateResponse(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) -> Int {
        guard let str = String(data: Data(bytes: buffer, count: bufferLen), encoding: .utf8) else { return -1 }
        let splitArr = str.components(separatedBy: "\r\n")
        var code = -1
        var i = 0
        var headers = [String: String]()
        for str in splitArr {
            if i == 0 {
                let responseSplit = str.components(separatedBy: .whitespaces)
                guard responseSplit.count > 1 else { return -1 }
                if let c = Int(responseSplit[1]) {
                    code = c
                }
            } else {
                let responseSplit = str.components(separatedBy: ":")
                guard responseSplit.count > 1 else { break }
                let key = responseSplit[0].trimmingCharacters(in: .whitespaces)
                let val = responseSplit[1].trimmingCharacters(in: .whitespaces)
                headers[key.lowercased()] = val
            }
            i += 1
        }
        advancedDelegate?.websocketHttpUpgrade(socket: self, response: str)
        onHttpResponseHeaders?(headers)
        if code != httpSwitchProtocolCode {
            return code
        }
        
        if let extensionHeader = headers[headerWSExtensionName.lowercased()] {
            processExtensionHeader(extensionHeader)
        }
        
        if let acceptKey = headers[headerWSAcceptName.lowercased()] {
            if acceptKey.count > 0 {
                if headerSecKey.count > 0 {
                    let sha = "\(headerSecKey)258EAFA5-E914-47DA-95CA-C5AB0DC85B11".sha1Base64()
                    if sha != acceptKey as String {
                        return -1
                    }
                }
                return 0
            }
        }
        return -1
    }

    /**
     Parses the extension header, setting up the compression parameters.
     */
    func processExtensionHeader(_ extensionHeader: String) {
        let parts = extensionHeader.components(separatedBy: ";")
        for p in parts {
            let part = p.trimmingCharacters(in: .whitespaces)
            if part == "permessage-deflate" {
                compressionState.supportsCompression = true
            } else if part.hasPrefix("server_max_window_bits=") {
                let valString = part.components(separatedBy: "=")[1]
                if let val = Int(valString.trimmingCharacters(in: .whitespaces)) {
                    compressionState.serverMaxWindowBits = val
                }
            } else if part.hasPrefix("client_max_window_bits=") {
                let valString = part.components(separatedBy: "=")[1]
                if let val = Int(valString.trimmingCharacters(in: .whitespaces)) {
                    compressionState.clientMaxWindowBits = val
                }
            } else if part == "client_no_context_takeover" {
                compressionState.clientNoContextTakeover = true
            } else if part == "server_no_context_takeover" {
                compressionState.serverNoContextTakeover = true
            }
        }
        if compressionState.supportsCompression {
            compressionState.decompressor = Decompressor(windowBits: compressionState.serverMaxWindowBits)
            compressionState.compressor = Compressor(windowBits: compressionState.clientMaxWindowBits)
        }
    }

    /**
     Read a 16 bit big endian value from a buffer
     */
    private static func readUint16(_ buffer: UnsafePointer<UInt8>, offset: Int) -> UInt16 {
        return (UInt16(buffer[offset + 0]) << 8) | UInt16(buffer[offset + 1])
    }

    /**
     Read a 64 bit big endian value from a buffer
     */
    private static func readUint64(_ buffer: UnsafePointer<UInt8>, offset: Int) -> UInt64 {
        var value = UInt64(0)
        for i in 0...7 {
            value = (value << 8) | UInt64(buffer[offset + i])
        }
        return value
    }

    /**
     Write a 16-bit big endian value to a buffer.
     */
    private static func writeUint16(_ buffer: UnsafeMutablePointer<UInt8>, offset: Int, value: UInt16) {
        buffer[offset + 0] = UInt8(value >> 8)
        buffer[offset + 1] = UInt8(value & 0xff)
    }

    /**
     Write a 64-bit big endian value to a buffer.
     */
    private static func writeUint64(_ buffer: UnsafeMutablePointer<UInt8>, offset: Int, value: UInt64) {
        for i in 0...7 {
            buffer[offset + i] = UInt8((value >> (8*UInt64(7 - i))) & 0xff)
        }
    }

    /**
     Process one message at the start of `buffer`. Return another buffer (sharing storage) that contains the leftover contents of `buffer` that I didn't process.
     */
    private func processOneRawMessage(inBuffer buffer: UnsafeBufferPointer<UInt8>) -> UnsafeBufferPointer<UInt8> {
        let response = readStack.last
        guard let baseAddress = buffer.baseAddress else {return emptyBuffer}
        let bufferLen = buffer.count
        if response != nil && bufferLen < 2 {
            fragBuffer = Data(buffer: buffer)
            return emptyBuffer
        }
        if let response = response, response.bytesLeft > 0 {
            var len = response.bytesLeft
            var extra = bufferLen - response.bytesLeft
            if response.bytesLeft > bufferLen {
                len = bufferLen
                extra = 0
            }
            response.bytesLeft -= len
            response.buffer?.append(Data(bytes: baseAddress, count: len))
            _ = processResponse(response)
            return buffer.fromOffset(bufferLen - extra)
        } else {
            let isFin = (FinMask & baseAddress[0])
            let receivedOpcodeRawValue = (OpCodeMask & baseAddress[0])
            let receivedOpcode = OpCode(rawValue: receivedOpcodeRawValue)
            let isMasked = (MaskMask & baseAddress[1])
            let payloadLen = (PayloadLenMask & baseAddress[1])
            var offset = 2
            if compressionState.supportsCompression && receivedOpcode != .continueFrame {
                compressionState.messageNeedsDecompression = (RSV1Mask & baseAddress[0]) > 0
            }
            if (isMasked > 0 || (RSVMask & baseAddress[0]) > 0) && receivedOpcode != .pong && !compressionState.messageNeedsDecompression {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(WSError(type: .protocolError, message: "masked and rsv data is not currently supported", code: Int(errCode)))
                writeError(errCode)
                return emptyBuffer
            }
            let isControlFrame = (receivedOpcode == .connectionClose || receivedOpcode == .ping)
            if !isControlFrame && (receivedOpcode != .binaryFrame && receivedOpcode != .continueFrame &&
                receivedOpcode != .textFrame && receivedOpcode != .pong) {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(WSError(type: .protocolError, message: "unknown opcode: \(receivedOpcodeRawValue)", code: Int(errCode)))
                    writeError(errCode)
                    return emptyBuffer
            }
            if isControlFrame && isFin == 0 {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(WSError(type: .protocolError, message: "control frames can't be fragmented", code: Int(errCode)))
                writeError(errCode)
                return emptyBuffer
            }
            var closeCode = CloseCode.normal.rawValue
            if receivedOpcode == .connectionClose {
                if payloadLen == 1 {
                    closeCode = CloseCode.protocolError.rawValue
                } else if payloadLen > 1 {
                    closeCode = WebSocket.readUint16(baseAddress, offset: offset)
                    if closeCode < 1000 || (closeCode > 1003 && closeCode < 1007) || (closeCode > 1013 && closeCode < 3000) {
                        closeCode = CloseCode.protocolError.rawValue
                    }
                }
                if payloadLen < 2 {
                    doDisconnect(WSError(type: .protocolError, message: "connection closed by server", code: Int(closeCode)))
                    writeError(closeCode)
                    return emptyBuffer
                }
            } else if isControlFrame && payloadLen > 125 {
                writeError(CloseCode.protocolError.rawValue)
                return emptyBuffer
            }
            var dataLength = UInt64(payloadLen)
            if dataLength == 127 {
                dataLength = WebSocket.readUint64(baseAddress, offset: offset)
                offset += MemoryLayout<UInt64>.size
            } else if dataLength == 126 {
                dataLength = UInt64(WebSocket.readUint16(baseAddress, offset: offset))
                offset += MemoryLayout<UInt16>.size
            }
            if bufferLen < offset || UInt64(bufferLen - offset) < dataLength {
                fragBuffer = Data(bytes: baseAddress, count: bufferLen)
                return emptyBuffer
            }
            var len = dataLength
            if dataLength > UInt64(bufferLen) {
                len = UInt64(bufferLen-offset)
            }
            if receivedOpcode == .connectionClose && len > 0 {
                let size = MemoryLayout<UInt16>.size
                offset += size
                len -= UInt64(size)
            }
            let data: Data
            if compressionState.messageNeedsDecompression, let decompressor = compressionState.decompressor {
                do {
                    data = try decompressor.decompress(bytes: baseAddress+offset, count: Int(len), finish: isFin > 0)
                    if isFin > 0 && compressionState.serverNoContextTakeover {
                        try decompressor.reset()
                    }
                } catch {
                    let closeReason = "Decompression failed: \(error)"
                    let closeCode = CloseCode.encoding.rawValue
                    doDisconnect(WSError(type: .protocolError, message: closeReason, code: Int(closeCode)))
                    writeError(closeCode)
                    return emptyBuffer
                }
            } else {
                data = Data(bytes: baseAddress+offset, count: Int(len))
            }

            if receivedOpcode == .connectionClose {
                var closeReason = "connection closed by server"
                if let customCloseReason = String(data: data, encoding: .utf8) {
                    closeReason = customCloseReason
                } else {
                    closeCode = CloseCode.protocolError.rawValue
                }
                doDisconnect(WSError(type: .protocolError, message: closeReason, code: Int(closeCode)))
                writeError(closeCode)
                return emptyBuffer
            }
            if receivedOpcode == .pong {
                if canDispatch {
                    callbackQueue.async { [weak self] in
                        guard let self = self else { return }
                        let pongData: Data? = data.count > 0 ? data : nil
                        self.onPong?(pongData)
                        self.pongDelegate?.websocketDidReceivePong(socket: self, data: pongData)
                    }
                }
                return buffer.fromOffset(offset + Int(len))
            }
            var response = readStack.last
            if isControlFrame {
                response = nil // Don't append pings.
            }
            if isFin == 0 && receivedOpcode == .continueFrame && response == nil {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(WSError(type: .protocolError, message: "continue frame before a binary or text frame", code: Int(errCode)))
                writeError(errCode)
                return emptyBuffer
            }
            var isNew = false
            if response == nil {
                if receivedOpcode == .continueFrame {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(WSError(type: .protocolError, message: "first frame can't be a continue frame", code: Int(errCode)))
                    writeError(errCode)
                    return emptyBuffer
                }
                isNew = true
                response = WSResponse()
                response!.code = receivedOpcode!
                response!.bytesLeft = Int(dataLength)
                response!.buffer = NSMutableData(data: data)
            } else {
                if receivedOpcode == .continueFrame {
                    response!.bytesLeft = Int(dataLength)
                } else {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(WSError(type: .protocolError, message: "second and beyond of fragment message must be a continue frame", code: Int(errCode)))
                    writeError(errCode)
                    return emptyBuffer
                }
                response!.buffer!.append(data)
            }
            if let response = response {
                response.bytesLeft -= Int(len)
                response.frameCount += 1
                response.isFin = isFin > 0 ? true : false
                if isNew {
                    readStack.append(response)
                }
                _ = processResponse(response)
            }

            let step = Int(offset + numericCast(len))
            return buffer.fromOffset(step)
        }
    }

    /**
     Process all messages in the buffer if possible.
     */
    private func processRawMessagesInBuffer(_ pointer: UnsafePointer<UInt8>, bufferLen: Int) {
        var buffer = UnsafeBufferPointer(start: pointer, count: bufferLen)
        repeat {
            buffer = processOneRawMessage(inBuffer: buffer)
        } while buffer.count >= 2
        if buffer.count > 0 {
            fragBuffer = Data(buffer: buffer)
        }
    }

    /**
     Process the finished response of a buffer.
     */
    private func processResponse(_ response: WSResponse) -> Bool {
        if response.isFin && response.bytesLeft <= 0 {
            if response.code == .ping {
                if respondToPingWithPong {
                    let data = response.buffer! // local copy so it is perverse for writing
                    dequeueWrite(data as Data, code: .pong)
                }
            } else if response.code == .textFrame {
                guard let str = String(data: response.buffer! as Data, encoding: .utf8) else {
                    writeError(CloseCode.encoding.rawValue)
                    return false
                }
                if canDispatch {
                    callbackQueue.async { [weak self] in
                        guard let self = self else { return }
                        self.onText?(str)
                        self.delegate?.websocketDidReceiveMessage(socket: self, text: str)
                        self.advancedDelegate?.websocketDidReceiveMessage(socket: self, text: str, response: response)
                    }
                }
            } else if response.code == .binaryFrame {
                if canDispatch {
                    let data = response.buffer! // local copy so it is perverse for writing
                    callbackQueue.async { [weak self] in
                        guard let self = self else { return }
                        self.onData?(data as Data)
                        self.delegate?.websocketDidReceiveData(socket: self, data: data as Data)
                        self.advancedDelegate?.websocketDidReceiveData(socket: self, data: data as Data, response: response)
                    }
                }
            }
            readStack.removeLast()
            return true
        }
        return false
    }

    /**
     Write an error to the socket
     */
    private func writeError(_ code: UInt16) {
        let buf = NSMutableData(capacity: MemoryLayout<UInt16>.size)
        let buffer = UnsafeMutableRawPointer(mutating: buf!.bytes).assumingMemoryBound(to: UInt8.self)
        WebSocket.writeUint16(buffer, offset: 0, value: code)
        dequeueWrite(Data(bytes: buffer, count: MemoryLayout<UInt16>.size), code: .connectionClose)
    }

    /**
     Used to write things to the stream
     */
    private func dequeueWrite(_ data: Data, code: OpCode, writeCompletion: (() -> ())? = nil) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            //stream isn't ready, let's wait
            guard let self = self else { return }
            guard let sOperation = operation else { return }
            var offset = 2
            var firstByte:UInt8 = self.FinMask | code.rawValue
            var data = data
            if [.textFrame, .binaryFrame].contains(code), let compressor = self.compressionState.compressor {
                do {
                    data = try compressor.compress(data)
                    if self.compressionState.clientNoContextTakeover {
                        try compressor.reset()
                    }
                    firstByte |= self.RSV1Mask
                } catch {
                    // TODO: report error?  We can just send the uncompressed frame.
                }
            }
            let dataLength = data.count
            let frame = NSMutableData(capacity: dataLength + self.MaxFrameSize)
            let buffer = UnsafeMutableRawPointer(frame!.mutableBytes).assumingMemoryBound(to: UInt8.self)
            buffer[0] = firstByte
            if dataLength < 126 {
                buffer[1] = CUnsignedChar(dataLength)
            } else if dataLength <= Int(UInt16.max) {
                buffer[1] = 126
                WebSocket.writeUint16(buffer, offset: offset, value: UInt16(dataLength))
                offset += MemoryLayout<UInt16>.size
            } else {
                buffer[1] = 127
                WebSocket.writeUint64(buffer, offset: offset, value: UInt64(dataLength))
                offset += MemoryLayout<UInt64>.size
            }
            buffer[1] |= self.MaskMask
            let maskKey = UnsafeMutablePointer<UInt8>(buffer + offset)
            _ = SecRandomCopyBytes(kSecRandomDefault, Int(MemoryLayout<UInt32>.size), maskKey)
            offset += MemoryLayout<UInt32>.size

            for i in 0..<dataLength {
                buffer[offset] = data[i] ^ maskKey[i % MemoryLayout<UInt32>.size]
                offset += 1
            }
            var total = 0
            while !sOperation.isCancelled {
                if !self.readyToWrite {
                    self.doDisconnect(WSError(type: .outputStreamWriteError, message: "output stream had an error during write", code: 0))
                    break
                }
                let stream = self.stream
                let writeBuffer = UnsafeRawPointer(frame!.bytes+total).assumingMemoryBound(to: UInt8.self)
                let len = stream.write(data: Data(bytes: writeBuffer, count: offset-total))
                if len <= 0 {
                    self.doDisconnect(WSError(type: .outputStreamWriteError, message: "output stream had an error during write", code: 0))
                    break
                } else {
                    total += len
                }
                if total >= offset {
                    if let callback = writeCompletion {
                        self.callbackQueue.async {
                            callback()
                        }
                    }

                    break
                }
            }
        }
        writeQueue.addOperation(operation)
    }

    /**
     Used to preform the disconnect delegate
     */
    private func doDisconnect(_ error: Error?) {
        guard !didDisconnect else { return }
        didDisconnect = true
        isConnecting = false
        mutex.lock()
        connected = false
        mutex.unlock()
        guard canDispatch else {return}
        callbackQueue.async { [weak self] in
            guard let self = self else { return }
            self.onDisconnect?(error)
            self.delegate?.websocketDidDisconnect(socket: self, error: error)
            self.advancedDelegate?.websocketDidDisconnect(socket: self, error: error)
            let userInfo = error.map{ [WebsocketDisconnectionErrorKeyName: $0] }
            NotificationCenter.default.post(name: NSNotification.Name(WebsocketDidDisconnectNotification), object: self, userInfo: userInfo)
        }
    }

    // MARK: - Deinit

    deinit {
        mutex.lock()
        readyToWrite = false
        cleanupStream()
        mutex.unlock()
        writeQueue.cancelAllOperations()
    }

}

private extension String {
    func sha1Base64() -> String {
        let data = self.data(using: String.Encoding.utf8)!
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA1($0, CC_LONG(data.count), &digest) }
        return Data(bytes: digest).base64EncodedString()
    }
}

private extension Data {

    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.init(bytes: buffer.baseAddress!, count: buffer.count)
    }

}

private extension UnsafeBufferPointer {

    func fromOffset(_ offset: Int) -> UnsafeBufferPointer<Element> {
        return UnsafeBufferPointer<Element>(start: baseAddress?.advanced(by: offset), count: count - offset)
    }

}

private let emptyBuffer = UnsafeBufferPointer<UInt8>(start: nil, count: 0)

#if swift(>=4)
#else
fileprivate extension String {
    var count: Int {
        return self.characters.count
    }
}
#endif

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SSLSecurity.swift
//  Starscream
//
//  Created by Dalton Cherry on 5/16/15.
//  Copyright (c) 2014-2016 Dalton Cherry.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////
#if os(Linux)
#else
import Foundation
import Security

protocol SSLTrustValidator {
    func isValid(_ trust: SecTrust, domain: String?) -> Bool
}

class SSLCert {
    var certData: Data?
    var key: SecKey?
    
    /**
     Designated init for certificates
     
     - parameter data: is the binary data of the certificate
     
     - returns: a representation security object to be used with
     */
    init(data: Data) {
        self.certData = data
    }
    
    /**
     Designated init for keys
     
     - parameter key: is the key to be used
     
     - returns: a representation security object to be used with
     */
    init(key: SecKey) {
        self.key = key
    }
}

class SSLSecurity : SSLTrustValidator {
    var validatedDN = true //should the domain name be validated?
    var validateEntireChain = true //should the entire cert chain be validated
    
    var isReady = false //is the key processing done?
    var certificates: [Data]? //the certificates
    var pubKeys: [SecKey]? //the keys
    var usePublicKeys = false //use keys or certificate validation?
    
    /**
     Use certs from main app bundle
     
     - parameter usePublicKeys: is to specific if the publicKeys or certificates should be used for SSL pinning validation
     
     - returns: a representation security object to be used with
     */
    convenience init(usePublicKeys: Bool = false) {
        let paths = Bundle.main.paths(forResourcesOfType: "cer", inDirectory: ".")
        
        let certs = paths.reduce([SSLCert]()) { (certs: [SSLCert], path: String) -> [SSLCert] in
            var certs = certs
            if let data = NSData(contentsOfFile: path) {
                certs.append(SSLCert(data: data as Data))
            }
            return certs
        }
        
        self.init(certs: certs, usePublicKeys: usePublicKeys)
    }
    
    /**
     Designated init
     
     - parameter certs: is the certificates or keys to use
     - parameter usePublicKeys: is to specific if the publicKeys or certificates should be used for SSL pinning validation
     
     - returns: a representation security object to be used with
     */
    init(certs: [SSLCert], usePublicKeys: Bool) {
        self.usePublicKeys = usePublicKeys
        
        if self.usePublicKeys {
            DispatchQueue.global(qos: .default).async {
                let pubKeys = certs.reduce([SecKey]()) { (pubKeys: [SecKey], cert: SSLCert) -> [SecKey] in
                    var pubKeys = pubKeys
                    if let data = cert.certData, cert.key == nil {
                        cert.key = self.extractPublicKey(data)
                    }
                    if let key = cert.key {
                        pubKeys.append(key)
                    }
                    return pubKeys
                }
                
                self.pubKeys = pubKeys
                self.isReady = true
            }
        } else {
            let certificates = certs.reduce([Data]()) { (certificates: [Data], cert: SSLCert) -> [Data] in
                var certificates = certificates
                if let data = cert.certData {
                    certificates.append(data)
                }
                return certificates
            }
            self.certificates = certificates
            self.isReady = true
        }
    }
    
    /**
     Valid the trust and domain name.
     
     - parameter trust: is the serverTrust to validate
     - parameter domain: is the CN domain to validate
     
     - returns: if the key was successfully validated
     */
    func isValid(_ trust: SecTrust, domain: String?) -> Bool {
        
        var tries = 0
        while !self.isReady {
            usleep(1000)
            tries += 1
            if tries > 5 {
                return false //doesn't appear it is going to ever be ready...
            }
        }
        var policy: SecPolicy
        if self.validatedDN {
            policy = SecPolicyCreateSSL(true, domain as NSString?)
        } else {
            policy = SecPolicyCreateBasicX509()
        }
        SecTrustSetPolicies(trust,policy)
        if self.usePublicKeys {
            if let keys = self.pubKeys {
                let serverPubKeys = publicKeyChain(trust)
                for serverKey in serverPubKeys as [AnyObject] {
                    for key in keys as [AnyObject] {
                        if serverKey.isEqual(key) {
                            return true
                        }
                    }
                }
            }
        } else if let certs = self.certificates {
            let serverCerts = certificateChain(trust)
            var collect = [SecCertificate]()
            for cert in certs {
                collect.append(SecCertificateCreateWithData(nil,cert as CFData)!)
            }
            SecTrustSetAnchorCertificates(trust,collect as NSArray)
            var result: SecTrustResultType = .unspecified
            SecTrustEvaluate(trust,&result)
            if result == .unspecified || result == .proceed {
                if !validateEntireChain {
                    return true
                }
                var trustedCount = 0
                for serverCert in serverCerts {
                    for cert in certs {
                        if cert == serverCert {
                            trustedCount += 1
                            break
                        }
                    }
                }
                if trustedCount == serverCerts.count {
                    return true
                }
            }
        }
        return false
    }
    
    /**
     Get the key from a certificate data
     
     - parameter data: is the certificate to pull the key from
     
     - returns: a key
     */
    func extractPublicKey(_ data: Data) -> SecKey? {
        guard let cert = SecCertificateCreateWithData(nil, data as CFData) else { return nil }
        
        return extractPublicKey(cert, policy: SecPolicyCreateBasicX509())
    }
    
    /**
     Get the key from a certificate
     
     - parameter data: is the certificate to pull the key from
     
     - returns: a key
     */
    func extractPublicKey(_ cert: SecCertificate, policy: SecPolicy) -> SecKey? {
        var possibleTrust: SecTrust?
        SecTrustCreateWithCertificates(cert, policy, &possibleTrust)
        
        guard let trust = possibleTrust else { return nil }
        var result: SecTrustResultType = .unspecified
        SecTrustEvaluate(trust, &result)
        return SecTrustCopyPublicKey(trust)
    }
    
    /**
     Get the certificate chain for the trust
     
     - parameter trust: is the trust to lookup the certificate chain for
     
     - returns: the certificate chain for the trust
     */
    func certificateChain(_ trust: SecTrust) -> [Data] {
        let certificates = (0..<SecTrustGetCertificateCount(trust)).reduce([Data]()) { (certificates: [Data], index: Int) -> [Data] in
            var certificates = certificates
            let cert = SecTrustGetCertificateAtIndex(trust, index)
            certificates.append(SecCertificateCopyData(cert!) as Data)
            return certificates
        }
        
        return certificates
    }
    
    /**
     Get the key chain for the trust
     
     - parameter trust: is the trust to lookup the certificate chain and extract the keys
     
     - returns: the keys from the certifcate chain for the trust
     */
    func publicKeyChain(_ trust: SecTrust) -> [SecKey] {
        let policy = SecPolicyCreateBasicX509()
        let keys = (0..<SecTrustGetCertificateCount(trust)).reduce([SecKey]()) { (keys: [SecKey], index: Int) -> [SecKey] in
            var keys = keys
            let cert = SecTrustGetCertificateAtIndex(trust, index)
            if let key = extractPublicKey(cert!, policy: policy) {
                keys.append(key)
            }
            
            return keys
        }
        
        return keys
    }
    
    
}
#endif

//
//  SSLClientCertificate.swift
//  Starscream
//
//  Created by Tomasz Trela on 08/03/2018.
//  Copyright © 2018 Vluxe. All rights reserved.
//

import Foundation

struct SSLClientCertificateError: LocalizedError {
    var errorDescription: String?
    
    init(errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

class SSLClientCertificate {
    internal let streamSSLCertificates: NSArray
    
    /**
     Convenience init.
     - parameter pkcs12Path: Path to pkcs12 file containing private key and X.509 ceritifacte (.p12)
     - parameter password: file password, see **kSecImportExportPassphrase**
     */
    convenience init(pkcs12Path: String, password: String) throws {
        let pkcs12Url = URL(fileURLWithPath: pkcs12Path)
        do {
            try self.init(pkcs12Url: pkcs12Url, password: password)
        } catch {
            throw error
        }
    }
    
    /**
     Designated init. For more information, see SSLSetCertificate() in Security/SecureTransport.h.
     - parameter identity: SecIdentityRef, see **kCFStreamSSLCertificates**
     - parameter identityCertificate: CFArray of SecCertificateRefs, see **kCFStreamSSLCertificates**
     */
    init(identity: SecIdentity, identityCertificate: SecCertificate) {
        self.streamSSLCertificates = NSArray(objects: identity, identityCertificate)
    }
    
    /**
     Convenience init.
     - parameter pkcs12Url: URL to pkcs12 file containing private key and X.509 ceritifacte (.p12)
     - parameter password: file password, see **kSecImportExportPassphrase**
     */
    convenience init(pkcs12Url: URL, password: String) throws {
        let importOptions = [kSecImportExportPassphrase as String : password] as CFDictionary
        do {
            try self.init(pkcs12Url: pkcs12Url, importOptions: importOptions)
        } catch {
            throw error
        }
    }
    
    /**
     Designated init.
     - parameter pkcs12Url: URL to pkcs12 file containing private key and X.509 ceritifacte (.p12)
     - parameter importOptions: A dictionary containing import options. A
     kSecImportExportPassphrase entry is required at minimum. Only password-based
     PKCS12 blobs are currently supported. See **SecImportExport.h**
     */
    init(pkcs12Url: URL, importOptions: CFDictionary) throws {
        do {
            let pkcs12Data = try Data(contentsOf: pkcs12Url)
            var rawIdentitiesAndCertificates: CFArray?
            let pkcs12CFData: CFData = pkcs12Data as CFData
            let importStatus = SecPKCS12Import(pkcs12CFData, importOptions, &rawIdentitiesAndCertificates)
            
            guard importStatus == errSecSuccess else {
                throw SSLClientCertificateError(errorDescription: "(Starscream) Error during 'SecPKCS12Import', see 'SecBase.h' - OSStatus: \(importStatus)")
            }
            guard let identitiyAndCertificate = (rawIdentitiesAndCertificates as? Array<Dictionary<String, Any>>)?.first else {
                throw SSLClientCertificateError(errorDescription: "(Starscream) Error - PKCS12 file is empty")
            }
            
            let identity = identitiyAndCertificate[kSecImportItemIdentity as String] as! SecIdentity
            var identityCertificate: SecCertificate?
            let copyStatus = SecIdentityCopyCertificate(identity, &identityCertificate)
            guard copyStatus == errSecSuccess else {
                throw SSLClientCertificateError(errorDescription: "(Starscream) Error during 'SecIdentityCopyCertificate', see 'SecBase.h' - OSStatus: \(copyStatus)")
            }
            self.streamSSLCertificates = NSArray(objects: identity, identityCertificate!)
        } catch {
            throw error
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Compression.swift
//
//  Created by Joseph Ross on 7/16/14.
//  Copyright © 2017 Joseph Ross.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Compression implementation is implemented in conformance with RFC 7692 Compression Extensions
//  for WebSocket: https://tools.ietf.org/html/rfc7692
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import zlib

class Decompressor {
    private var strm = z_stream()
    private var buffer = [UInt8](repeating: 0, count: 0x2000)
    private var inflateInitialized = false
    private let windowBits:Int
    
    init?(windowBits:Int) {
        self.windowBits = windowBits
        guard initInflate() else { return nil }
    }
    
    private func initInflate() -> Bool {
        if Z_OK == inflateInit2_(&strm, -CInt(windowBits),
                                 ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
        {
            inflateInitialized = true
            return true
        }
        return false
    }
    
    func reset() throws {
        teardownInflate()
        guard initInflate() else { throw WSError(type: .compressionError, message: "Error for decompressor on reset", code: 0) }
    }
    
    func decompress(_ data: Data, finish: Bool) throws -> Data {
        return try data.withUnsafeBytes { (bytes:UnsafePointer<UInt8>) -> Data in
            return try decompress(bytes: bytes, count: data.count, finish: finish)
        }
    }
    
    func decompress(bytes: UnsafePointer<UInt8>, count: Int, finish: Bool) throws -> Data {
        var decompressed = Data()
        try decompress(bytes: bytes, count: count, out: &decompressed)
        
        if finish {
            let tail:[UInt8] = [0x00, 0x00, 0xFF, 0xFF]
            try decompress(bytes: tail, count: tail.count, out: &decompressed)
        }
        
        return decompressed
        
    }
    
    private func decompress(bytes: UnsafePointer<UInt8>, count: Int, out:inout Data) throws {
        var res:CInt = 0
        strm.next_in = UnsafeMutablePointer<UInt8>(mutating: bytes)
        strm.avail_in = CUnsignedInt(count)
        
        repeat {
            strm.next_out = UnsafeMutablePointer<UInt8>(&buffer)
            strm.avail_out = CUnsignedInt(buffer.count)
            
            res = inflate(&strm, 0)
            
            let byteCount = buffer.count - Int(strm.avail_out)
            out.append(buffer, count: byteCount)
        } while res == Z_OK && strm.avail_out == 0
        
        guard (res == Z_OK && strm.avail_out > 0)
            || (res == Z_BUF_ERROR && Int(strm.avail_out) == buffer.count)
            else {
                throw WSError(type: .compressionError, message: "Error on decompressing", code: 0)
        }
    }
    
    private func teardownInflate() {
        if inflateInitialized, Z_OK == inflateEnd(&strm) {
            inflateInitialized = false
        }
    }
    
    deinit {
        teardownInflate()
    }
}

class Compressor {
    private var strm = z_stream()
    private var buffer = [UInt8](repeating: 0, count: 0x2000)
    private var deflateInitialized = false
    private let windowBits:Int
    
    init?(windowBits: Int) {
        self.windowBits = windowBits
        guard initDeflate() else { return nil }
    }
    
    private func initDeflate() -> Bool {
        if Z_OK == deflateInit2_(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                 -CInt(windowBits), 8, Z_DEFAULT_STRATEGY,
                                 ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size))
        {
            deflateInitialized = true
            return true
        }
        return false
    }
    
    func reset() throws {
        teardownDeflate()
        guard initDeflate() else { throw WSError(type: .compressionError, message: "Error for compressor on reset", code: 0) }
    }
    
    func compress(_ data: Data) throws -> Data {
        var compressed = Data()
        var res:CInt = 0
        data.withUnsafeBytes { (ptr:UnsafePointer<UInt8>) -> Void in
            strm.next_in = UnsafeMutablePointer<UInt8>(mutating: ptr)
            strm.avail_in = CUnsignedInt(data.count)
            
            repeat {
                strm.next_out = UnsafeMutablePointer<UInt8>(&buffer)
                strm.avail_out = CUnsignedInt(buffer.count)
                
                res = deflate(&strm, Z_SYNC_FLUSH)
                
                let byteCount = buffer.count - Int(strm.avail_out)
                compressed.append(buffer, count: byteCount)
            }
                while res == Z_OK && strm.avail_out == 0
            
        }
        
        guard res == Z_OK && strm.avail_out > 0
            || (res == Z_BUF_ERROR && Int(strm.avail_out) == buffer.count)
            else {
                throw WSError(type: .compressionError, message: "Error on compressing", code: 0)
        }
        
        compressed.removeLast(4)
        return compressed
    }
    
    private func teardownDeflate() {
        if deflateInitialized, Z_OK == deflateEnd(&strm) {
            deflateInitialized = false
        }
    }
    
    deinit {
        teardownDeflate()
    }
}
