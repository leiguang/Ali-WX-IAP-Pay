//
//  IAPHud.swift
//  雅思哥
//
//  Created by 雷广 on 2018/1/10.
//  Copyright © 2018年 chutzpah. All rights reserved.
//

import Foundation
import MBProgressHUD

class IAPHud {
    
    func showWithStatus(_ status: IAPStatus) {
        switch status {
            
        // 1.失败
        case .unableToPay:
            showMessage("您已禁止应用内购买", detail: "请在系统设置中打开内购功能后重试")
        case .createOrderBeforePayFailed(let errMsg):
            showMessage("创建订单失败", detail: errMsg)
        case .productRequestFailed(let errMsg):
            showMessage("获取产品信息失败", detail: errMsg)
        case .deferred:
            showMessage("您的Apple Id暂无购买权限", detail: "例如小孩购买，尚无权限，需等待家人给Apple Id账号赋值权限")
        case .paymentFailed(let errMsg):
            showMessage("支付失败", detail: errMsg)
        case .paymentCancelled:
            showMessage("您已取消支付", hideAfterDelay: 1.0)
        case .receiptValidationFailed(let errMsg):
            self.hud.hide(animated: false)
            showAlertValidateReceiptFailed("支付凭证验证失败, \(errMsg)")
            
        // 2.进行中
        case .createOrderBeforePayStart:
            showLoadingMessage("正在生成订单...")
        case .createOrderBeforePaySuccess:
            showLoadingMessage("创建订单成功")
        case .productRequestStart:
            showLoadingMessage("获取产品信息中...")
        case .productRequestSuccess:
            showLoadingMessage("获取产品信息成功")
        case .purchasing:
            showLoadingMessage("请求支付中...", detail: "支付过程可能较慢，请耐心等候")
        case .restored:
            showLoadingMessage("已购商品，恢复购买")
        case .purchased:
            showLoadingMessage("支付成功，准备验证凭据")
        case .receiptValidateStart:
            showLoadingMessage("正在验证凭证的有效性")
            
        // 3.成功
        case .receiptValidationSuccess:
            showMessage("购买成功", hideAfterDelay: 1.0)    // 同时界面上也会有购买成的提示
        }
    }
    
    // MARK: - MBProgressHUD
    private lazy var hud: MBProgressHUD = {
        let hud = MBProgressHUD(frame: UIScreen.main.bounds)
        hud.backgroundView.style = .solidColor
        hud.backgroundView.color = UIColor(white: 0, alpha: 0.5)
        hud.removeFromSuperViewOnHide = true
        return hud
    }()
    
    /// 1.5s 后消失
    func showMessage(_ message: String, detail: String = "", hideAfterDelay: TimeInterval = 2.0) {
        hud.mode = .text
        hud.label.text = message
        hud.detailsLabel.text = detail
        hud.removeFromSuperViewOnHide = true
        UIApplication.shared.keyWindow?.addSubview(hud)
        hud.show(animated: false)
        DispatchQueue.main.async {
            self.hud.hide(animated: false, afterDelay: hideAfterDelay)
        }
    }
    
    /// 转圈，需手动hide
    func showLoadingMessage(_ message: String, detail: String = "") {
        hud.mode = .indeterminate
        hud.label.text = message
        hud.detailsLabel.text = detail
        UIApplication.shared.keyWindow?.addSubview(hud)
        hud.show(animated: false)
    }
    
    
    /// 凭据验证失败的弹框，点击“知道了”的回调
    var validateReceiptFailedKnowCallback: (()->Void)?
    
    /// 凭据验证失败的提示框
    func showAlertValidateReceiptFailed(_ errMsg: String) {
        self.hud.hide(animated: false)
        
        let attrs = String.attributesWith(font: UIFont.systemFont(ofSize: 15), color: Color.textBlack, characterSpace: 0.0, lineSpace: 6.0)
        let attrsBlue = String.attributesWith(font: UIFont.systemFont(ofSize: 15), color: Color.themeBlue, characterSpace: 0.0, lineSpace: 6.0)
        
        let text = NSMutableAttributedString(string: "")
        let text1 = NSAttributedString(string: "如付款后遇到问题，请将遇到的问题发送至 ", attributes: attrs)
        let text2 = NSAttributedString(string: "help@ieltsbro.org", attributes: attrsBlue)
        let text3 = NSAttributedString(string: "，并附上第三方支付平台的订单号（如有）和你的注册手机号，我们会尽快排查问题!", attributes: attrs)
        text.append(text1)
        text.append(text2)
        text.append(text3)
        
        let alertView = IAPPayKnowPopupView(attrsText: text)
        alertView.knowHandler = self.validateReceiptFailedKnowCallback
        alertView.show()
    }
}
