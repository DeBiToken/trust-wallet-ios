// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import WebKit
import JavaScriptCore

extension WKWebViewConfiguration {

    static func make(for account: Wallet, with sessionConfig: Config, in messageHandler: WKScriptMessageHandler) -> WKWebViewConfiguration {
        let address = account.address.description.lowercased()
        let config = WKWebViewConfiguration()
        var js = ""

        guard
            let bundlePath = Bundle.main.path(forResource: "TrustWeb3Provider", ofType: "bundle"),
            let bundle = Bundle(path: bundlePath) else { return config }

        if let filepath = bundle.path(forResource: "trust-min", ofType: "js") {
            do {
                js += try String(contentsOfFile: filepath)
            } catch { }
        }

        js +=
        """
        const addressHex = "\(address)"
        const rpcUrl = "\(sessionConfig.server.rpcURL.absoluteString)"
        const wssUrl = "\(sessionConfig.server.wssURL.absoluteString)"
        const chainID = "\(sessionConfig.chainID)"

        function executeCallback (id, error, value) {
          trust.executeCallback(id, error, value)
        }

        const trust = new Trust({
          rpcUrl,
          address: addressHex,
          networkVersion: chainID,
          getAccounts: function (cb) { cb(null, [addressHex]) },
          processTransaction: function (tx, cb){
            console.log('signing a transaction', tx)
            const { id = 8888 } = tx
            trust.addCallback(id, cb)
            webkit.messageHandlers.signTransaction.postMessage({"name": "signTransaction", "object": tx, id: id})
          },
          signMessage: function (msgParams, cb) {
            const { data } = msgParams
            const { id = 8888 } = msgParams
            console.log("signing a message", msgParams)
            trust.addCallback(id, cb)
            webkit.messageHandlers.signMessage.postMessage({"name": "signMessage", "object": { data }, id: id})
        },
          signPersonalMessage: function (msgParams, cb) {
            const { data } = msgParams
            const { id = 8888 } = msgParams
            console.log("signing a personal message", msgParams)
            trust.addCallback(id, cb)
            webkit.messageHandlers.signPersonalMessage.postMessage({"name": "signPersonalMessage", "object": { data }, id: id})
          },
            signTypedMessage: function (msgParams, cb) {
            const { data } = msgParams
            const { id = 8888 } = msgParams
            console.log("signing a typed message", msgParams)
            trust.addCallback(id, cb)
            webkit.messageHandlers.signTypedMessage.postMessage({"name": "signTypedMessage", "object": { data }, id: id})
            }
        })

        web3.setProvider = function () {
          console.debug('Trust Wallet - overrode web3.setProvider')
        }

        web3.eth.defaultAccount = addressHex

        web3.version.getNetwork = function(cb) {
            cb(null, chainID)
        }
        web3.eth.getCoinbase = function(cb) {
            return cb(null, addressHex)
        }

        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.add(messageHandler, name: Method.signTransaction.rawValue)
        config.userContentController.add(messageHandler, name: Method.signPersonalMessage.rawValue)
        config.userContentController.add(messageHandler, name: Method.signMessage.rawValue)
        config.userContentController.add(messageHandler, name: Method.signTypedMessage.rawValue)
        config.userContentController.addUserScript(userScript)
        return config
    }
}
