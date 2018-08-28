//
//  IAPKeychain.swift
//  雅思哥
//
//  Created by 雷广 on 2018/1/9.
//  Copyright © 2018年 chutzpah. All rights reserved.
//

import Foundation
import KeychainAccess

/// 存储到keychain中的receipt模型
struct IAPReceipt: Codable {
    let orderId: Int             // 订单id数组
    let quantity: Int               // 购买的数量
    let productIdentifier: String   // 产品identifier
    let receiptString: String       // 购买凭据，base64编码后的字符串
}

extension IAPReceipt: Equatable {
    static func == (lhs: IAPReceipt, rhs: IAPReceipt) -> Bool {
        return lhs.orderId == rhs.orderId &&
            lhs.quantity == rhs.quantity &&
            lhs.productIdentifier == rhs.productIdentifier &&
            lhs.receiptString == rhs.receiptString
    }
}

class IAPKeychain {
    
    let keychain: Keychain
    
    init(service: String) {
        self.keychain = Keychain(service: service)
    }
    
    /// 检查是否有未验证的receipt
    func isExistReceipt() -> Bool {
        return keychain.allKeys().count > 0 ? true : false
    }
    
    /// 保存receipt
    func saveReceipt(_ receipt: IAPReceipt) {
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        let key = "\(receipt.orderId)"
        keychain[data: key] = data
    }
    
    /// 移除receipt
    func removeReceipt(_ receipt: IAPReceipt) {
        let key = "\(receipt.orderId)"
        keychain[key] = nil
    }
    
    /// 获取所有receipt
    func allReceipts() -> [IAPReceipt] {
        var receipts: [IAPReceipt] = []
        for key in keychain.allKeys() {
            guard let data = keychain[data: key], let receipt = try? JSONDecoder().decode(IAPReceipt.self, from: data) else { continue }
            receipts.append(receipt)
        }
        return receipts
    }
    
    /// 移除所有receipt
    func removeAllReceipts() {
        do { try keychain.removeAll() } catch {}
    }
}
