//
//  ViewController.swift
//  Ali-WX-IAP-Pay
//
//  Created by 雷广 on 2018/8/28.
//  Copyright © 2018年 leiguang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
//        RechargeManager.reqRechargeInfo { [weak self] (model) in
//            if model.isIAP {    // 苹果充值
//                let vc = RechargeIAPViewController(balance: model.balance, items: model.iapItems)
//                self?.present(vc, animated: false, completion: nil)
//            } else {            // 微信、支付宝充值
//                let vc = RechargeViewController(balance: model.balance, items: model.items)
//                self?.present(vc, animated: false, completion: nil)
//            }
//        }
        
        
        // 点击微信支付
//        WXApiManager.pay(rechargeMoney)
        
        
        // 点击支付宝支付
//        AlipayManager.pay(rechargeMoney)
        
    }

}

