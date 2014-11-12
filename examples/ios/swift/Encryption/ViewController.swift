////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm
import Security
import UIKit

// Model definition
class EncryptionObject: RLMObject {
    dynamic var stringProp = ""
}

class ViewController: UIViewController {
    var textView: UITextView!

    // Create a view to display output in
    override func loadView() {
        let applicationFrame = UIScreen.mainScreen().applicationFrame
        self.view = UIView(frame: applicationFrame)
        self.view.backgroundColor = UIColor.whiteColor()

        self.textView = UITextView(frame: applicationFrame)
        self.view.addSubview(self.textView)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        // Use an autorelease pool to close the Realm at the end of the block, so
        // that we can try to reopen it with different keys
        autoreleasepool {
            let realm = RLMRealm.encryptedRealmWithPath(RLMRealm.defaultRealmPath(),
                key: self.getKey(), readOnly: false, error: nil)

            // Add an object
            realm.transactionWithBlock {
                let obj = EncryptionObject()
                obj.stringProp = "abcd"
                realm.addObject(obj)
            }
        }

        // Opening with wrong key fails since it decrypts to the wrong thing
        autoreleasepool {
            var error: NSError? = nil
            RLMRealm.encryptedRealmWithPath(RLMRealm.defaultRealmPath(),
                key: "1234567890123456789012345678901234567890123456789012345678901234".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false),
                readOnly: false, error: &error)
            self.log("Open with wrong key: \(error)")
        }

        // Opening wihout supplying a key at all fails
        autoreleasepool {
            var error: NSError? = nil
            RLMRealm(path: RLMRealm.defaultRealmPath(), readOnly: false, error: &error)
            self.log("Open with no key: \(error)")
        }

        // Reopening with the correct key works and can read the data
        autoreleasepool {
            let realm = RLMRealm.encryptedRealmWithPath(RLMRealm.defaultRealmPath(),
                key: self.getKey(), readOnly: false, error: nil)

            self.log("Saved object: \((EncryptionObject.allObjectsInRealm(realm).firstObject()! as EncryptionObject).stringProp)")
        }
    }

    func log(text: String) {
        self.textView.text = self.textView.text + text + "\n\n"
    }

    func getKey() -> NSData {
        // Identifier for our keychain entry - should be unique for your application
        let keychainIdentifier = "io.Realm.EncryptionExampleKey"
        let keychainIdentifierData = keychainIdentifier.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)

        // First check in the keychain for an existing key
        var query: NSDictionary = [
            (kSecClass as NSString): kSecClassKey,
            (kSecAttrApplicationTag as NSString): keychainIdentifierData!,
            (kSecAttrKeySizeInBits as NSString): 512,
            (kSecReturnData as NSString): true
        ]

        var dataTypeRef: Unmanaged<AnyObject>?
        var status = SecItemCopyMatching(query, &dataTypeRef)
        if status == errSecSuccess {
            return dataTypeRef?.takeUnretainedValue() as NSData
        }

        // No pre-existing key from this application, so generate a new one
        let keyData = NSMutableData(length: 64)!
        let result = SecRandomCopyBytes(kSecRandomDefault, 64, UnsafeMutablePointer<UInt8>(keyData.mutableBytes))

        // Store the key in the keychain
        query = [
            (kSecClass as NSString): kSecClassKey,
            (kSecAttrApplicationTag as NSString): keychainIdentifierData!,
            (kSecAttrKeySizeInBits as NSString): 512,
            (kSecValueData as NSString): keyData
        ]

        status = SecItemAdd(query, nil)
        assert(status == errSecSuccess, "Failed to insert the new key in the keychain")

        return keyData;
    }
}
