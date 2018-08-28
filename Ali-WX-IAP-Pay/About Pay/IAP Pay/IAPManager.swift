//
//  IAPManager.swift
//  雅思哥
//
//  Created by 雷广 on 2017/12/22.
//  Copyright © 2017年 chutzpah. All rights reserved.
//
// 参考文档：
// 苹果内购指南 [In-App Purchase Programming Guide](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction.html#//apple_ref/doc/uid/TP40008267-CH1-SW1)
// 收据验证 [Receipt Validation Programming Guide](https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Introduction.html#//apple_ref/doc/uid/TP40010573-CH105-SW1)

import Foundation
import StoreKit
import MBProgressHUD
import KeychainAccess
import CryptoSwift

/**
苹果内购的商品id:
6元学贝礼包 "***.xuebei.6rmb"
12元学贝礼包 "***.xuebei.12rmb"
30元学贝礼包 "***.xuebei.30rmb"
68元学贝礼包 "***.xuebei.68rmb"
128元学贝礼包 "***.xuebei.128rmb"
698元学贝礼包 "***.xuebei.698rmb"
*/


/// 请使用 IAPManager.shared 单例对象
class IAPManager: NSObject {
    
    static let shared = IAPManager()
    
    /// 支付购买状态回调
    var statusCallback: ((IAPStatus)->Void)?
    
    /// 凭据验证失败的弹框，点击“知道了”的回调
    var validateReceiptFailedKnowCallback: (()->Void)?
    
    /// 回调状态的时候，是否显示 hud，默认显示
    var showHud: Bool = true
    
    private var request: SKProductsRequest?     // 验证获取产品信息的request
    private var quantity: Int = 1               // 购买数量
    private var productIdentifier: String = ""   // 购买产品的identifier
    private var orderId: Int = 0                // 创建支付订单的返回的order_id, 存起来用于验证凭据时再发给服务器
    
    /// 用于存储支付凭据的keychain
    private lazy var keychain: IAPKeychain = { return IAPKeychain(service: "kHcpIAPKeychainService") }()
    ///
    private lazy var hud: IAPHud = { return IAPHud() }()
    
    
    /// 把statusCallback包装一层，用于show hud，展示支付状态
    private func statusCallbackInner(_ status: IAPStatus) -> Void  {
        print("IAP purchase status: \(status)")
        
        // 这句赋值代码要在下一行的 hud.showWithStatus() 前面，否则不会回调
        if case .receiptValidationFailed = status {
            hud.validateReceiptFailedKnowCallback = self.validateReceiptFailedInnerCallback
        }
        
        if self.showHud {
            hud.showWithStatus(status)
        }
        
        statusCallback?(status)
        
        
        // 如果status状态为 成功/失败， (注意：如果有自动连续支付两次的情形，就不要重置闭包statusCallback为nil，因为在新订单页面，连续支付两次时穿行的，第一次的重置是在第二次支付发起后执行，会把第二次的回调变成nil)
        if status.isSuccess || status.isFailed {
            statusCallback = nil
            showHud = true  // 默认显示hud，设置不显示的话需在状态回调前设置为false
        }
    }
    
    private func validateReceiptFailedInnerCallback() -> Void {
        if self.validateReceiptFailedKnowCallback != nil {
            self.validateReceiptFailedKnowCallback!()
            self.validateReceiptFailedKnowCallback = nil    // 调用后重置为nil，避免闭包内的对象销毁后，闭包还对其调用导致的bug
        }
    }
    
    
    private override init() {
        super.init()
        
        // 在didFinishLaunchingWithOptions中 监听购买结果 SKPaymentQueue.default().add(IAPManager.shared)
        
        /// 每次用户登录成功之后，检查本地是否有未验证的IAP凭据
//        NotificationCenter.default.addObserver(self, selector: #selector(checkAndValidateLocalReceipt), name: HcpNotificationName.loginSuccess, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.checkAndValidateLocalReceipt()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// 在didFinishLaunchingWithOptions中 监听购买结果
    @objc static func setup() {
        SKPaymentQueue.default().add(IAPManager.shared)
    }
    
    
    // MARK: - Hcp 购买接口
    
    /// 购买
    /// - Parameters:
    ///     - productIdentifier: 内购商品的id (6元学贝礼包、688元学贝礼包...)
    ///     - orderId: 服务器返回的订单id
    func buy(_ productIdentifier: String, money: Double) {
        guard checkBeforPay() == true else { return }
        self.productIdentifier = productIdentifier
//        self.orderId = orderId
        
        createOrderBeforPay(money: money)
    }
    
    
    /// 在支付之前需要执行的检查操作
    /// - Returns: true 表示检查成功，可以继续支付； false 表示不成功，会有提示，停止支付
    private func checkBeforPay() -> Bool {
        // AppleId账户是否允许支付
        guard SKPaymentQueue.canMakePayments() else {
            statusCallbackInner(.unableToPay)
            return false
        }
        
        // 每次支付前，先检查本地是否有未验证的凭据，若有，则先去验证凭据，暂不支付
        guard !keychain.isExistReceipt() else {
            checkAndValidateLocalReceipt()
            return false
        }
        
        return true
    }
    
    /// 去App Store验证要购买的产品信息是否有效 （参数：productIdentifiers）
    private func getProductInfo() {
        let productsRequest = SKProductsRequest(productIdentifiers: Set([self.productIdentifier]))
        // Keep a strong reference to the request.
        self.request = productsRequest
        productsRequest.delegate = self
        productsRequest.start()
        
        statusCallbackInner(.productRequestStart)
    }
}


// MARK: - 确认订单接口（支付之前，向后台确认此订单是否还有效，包括是否过期、是否已支付过）
extension IAPManager {
    func createOrderBeforPay(money: Double) {
        statusCallbackInner(.createOrderBeforePayStart)
        let params: [String: Any] = ["should_pay": money,
                                     "token": kUserToken]
        HttpManager.requestJson(.iap_pay_create_order, params: params, justContent: true, autoHandleHud: false) { (result) in
            guard result.isSuccess, let content = result.value else {
                self.statusCallbackInner(.createOrderBeforePayFailed(String(describing: result.error!)))
                return
            }
            guard let orderId = content["id"] as? Int else {
                self.statusCallbackInner(.createOrderBeforePayFailed(HttpError.invalidData.localizedDescription))
                return
            }
            self.orderId = orderId
            self.statusCallbackInner(.createOrderBeforePaySuccess)
            // 创建订单成功之后，获取产品信息
            self.getProductInfo()
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        
        for invalidIdentifier in response.invalidProductIdentifiers {
            // Handle any invalid product identifiers.
            print("invalidProductIdentifier: \(invalidIdentifier)")
        }
        
        if response.products.isEmpty {
            statusCallbackInner(.productRequestFailed("未获取到产品信息"))
            return
        }
        
        for product in response.products {
            statusCallbackInner(.productRequestSuccess)
            print("product.price: \(product.price), priceLocale: \(product.priceLocale), localizedTitle: \(product.localizedTitle), localizedDescription: \(product.localizedDescription)")
            // 请求支付
            let payment = SKMutablePayment(product: product)
            payment.quantity = self.quantity
            SKPaymentQueue.default().add(payment)
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        statusCallbackInner(.productRequestFailed(error.localizedDescription))
    }
}


// MARK: - SKPaymentTransactionObserver
extension IAPManager: SKPaymentTransactionObserver {
    
    // 当用户的购买操作有结果时，触发下面回调函数
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:   // 商品添加进列表 Update your UI to reflect the in-progress status, and wait to be called again.
                statusCallbackInner(.purchasing)
                
            case .deferred:     // 如小孩购买，尚无权限，需等待家人给权限
                statusCallbackInner(.deferred)
                
            case .restored:     // 已购商品，恢复购买 (本Hcp项目中都是消耗品，未使用到restored)
                statusCallbackInner(.restored)
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .purchased:    // 购买成功
                statusCallbackInner(.purchased)
                
                if let url = Bundle.main.appStoreReceiptURL,
                    let receiptData = try? Data(contentsOf: url) {
                    let receiptString = receiptData.base64EncodedString()
                    
                    // 1. 先把receipt保存到本地，服务端验证完成后再删除，防止网络连接失败导致丢单
                    let receipt = IAPReceipt(
                            orderId: self.orderId,
                            quantity: self.quantity,
                            productIdentifier: transaction.payment.productIdentifier,
                            receiptString: receiptString)
                    keychain.saveReceipt(receipt)
                    
                    // 2. 把receipt发送到服务器验证是否有效
                    validateReceipt(receipt)
                    
                } else {    // 这一步应该永远不会执行
                    statusCallbackInner(.receiptValidationFailed("未获取到本地购买凭证数据"))
                }
                
                SKPaymentQueue.default().finishTransaction(transaction)
                
            case .failed:       // 购买失败 For a list of error constants, see SKErrorDomain.
                if let error = (transaction.error as NSError?), error.code == SKError.paymentCancelled.rawValue {
                    statusCallbackInner(.paymentCancelled)
                } else {
                    statusCallbackInner(.paymentFailed(transaction.error!.localizedDescription))
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            }
        }
    }
}


// MARK: - Receipt 管理

extension IAPManager {

    /// 检查本地未验证的receipt，如果有，则自动去服务器验证
    @objc func checkAndValidateLocalReceipt() {
        if keychain.isExistReceipt() {
            self.showHud = false    // 在这里重写提示，完成后再重置为yes
            self.statusCallback = { [weak self] status in
                if case .receiptValidateStart = status {
                    self?.hud.showLoadingMessage("检查到本地有未验证的支付凭证", detail: "验证中...")
                }
                if case .receiptValidationSuccess = status {
                    self?.hud.showMessage("支付凭据验证成功", detail: "购买的商品已发放到您的账户", hideAfterDelay: 2.0)
                    self?.showHud = true    // 验证流程结束后重置为true
                }
                if case .receiptValidationFailed(let errMsg) = status {
                    self?.hud.showAlertValidateReceiptFailed(errMsg)
                    self?.showHud = true    // 验证流程结束后重置为true
                }
            }
            validateLocalReceipts()
        }
    }

    /// 把本地的存有的receipt，发给服务器验证
    private func validateLocalReceipts() {
        for receipt in keychain.allReceipts() {
            validateReceipt(receipt)
        }
    }

    /// 向服务器验证购买凭证的有效性
    private func validateReceipt(_ receipt: IAPReceipt) {
        statusCallbackInner(.receiptValidateStart)

        let secret = encryptReceipt(receipt.receiptString, orderId: receipt.orderId, secretKey: secretKey)
        
        let params: [String: Any] = ["order_id": "\(receipt.orderId)",
                                     "device_proof": receipt.receiptString,
                                     "secret": secret]

        HttpManager.requestJson(.iappay_sign_verify, params: params, justContent: false, autoHandleHud: false) { (result) in
            guard result.isSuccess else {
                if case HttpError.business = (result.error as! HttpError) {
                    // 如果是Hcp服务器返回500的错误，则移除本地receipt并提示错误信息
                    // 先移除本地对应receipt，再回调
                    self.keychain.removeReceipt(receipt)
                }
                self.statusCallbackInner(.receiptValidationFailed(String(describing: result.error!)))
                return
            }
            
            // 先移除本地对应receipt，再回调
            self.keychain.removeReceipt(receipt)
            self.statusCallbackInner(.receiptValidationSuccess)
            
            // 购买成功之后，需要发通知 更新页面
            NotificationCenter.default.post(name: NotificationName.rechargeWalletPaySuccess, object: nil)
        }

    
        

//        let requestContents = ["receipt-data": receipt]
//        guard let requestData = try? JSONSerialization.data(withJSONObject: requestContents, options: []) else {
//            statusCallbackInner(.receiptValidationFailed("购买凭证数据转data有误"))
//            return
//        }
//
//        enum ValidationReceiptUrl: String {
//            case sandBox    = "https://sandbox.itunes.apple.com/verifyReceipt"
//            case appStore   = "https://buy.itunes.apple.com/verifyReceipt"
//        }
//        //                二次验证，测试用沙盒验证，App Store审核的时候也使用的是沙盒购买，所以验证购买凭证的时候需要判断返回Status Code决定是否去沙盒进行二次验证，为了线上用户的使用，验证的顺序肯定是先验证正式环境，此时若返回值为21007，就需要去沙盒二次验证，因为此购买的是在沙盒进行的。
//
//        var request = URLRequest(url: URL(string: ValidationReceiptUrl.sandBox.rawValue)!)
//        request.httpMethod = "POST"
//        request.httpBody = requestData
//
//        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
//
//            DispatchQueue.main.async {
//                guard error == nil else {
//                    self.statusCallbackInner(.receiptValidationNetworkFailed(error!.localizedDescription))
//                    return
//                }
//
//                guard let data = data,
//                    let jsonResponse = try? JSONSerialization.jsonObject(with: data, options: []),
//                    let jsonDict = jsonResponse as? [String: Any],
//                    let status = jsonDict["status"] as? Int else {
//                        self.statusCallbackInner(.receiptValidationFailed("返回数据错误"))
//                        return
//                }
//                print("jsonResponse: \(jsonResponse)")
//
//                // 移除本地对应receipt
//                self.removeReceipt(key: key)
//
//                if status == 0 {    // 购买凭证验证成功
//                    self.statusCallbackInner(.receiptValidationSuccess)
//                } else {
//                    self.statusCallbackInner(.receiptValidationFailed("error code: \(status)"))
//                }
//                // status 错误码详情见：https://developer.apple.com/library/content/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html#//apple_ref/doc/uid/TP40010573-CH104-SW2
//            }
//        })
//        task.resume()
    }
    
    
    
}

fileprivate let secretKey = "****************************"  // *** 自定义
fileprivate func encryptReceipt(_ recipt: String, orderId: Int, secretKey: String) -> String{
    let toEncyptString = "\(orderId)" + secretKey + recipt
    let result = toEncyptString.md5().sha512()  // *** 自定义，如 toEncyptString.md5().sha512().md5()之类
    return result
}

