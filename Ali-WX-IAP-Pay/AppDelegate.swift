//
//  AppDelegate.swift
//  Ali-WX-IAP-Pay
//
//  Created by 雷广 on 2018/8/28.
//  Copyright © 2018年 leiguang. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // 向微信注册
        WXApi.registerApp("******") // 另："info.plist"、"URL Types"中也要相应填写，见微信支付文档
        
        // 在didFinishLaunchingWithOptions中 监听购买结果, 处理未finish的transaction
        IAPManager.setup()
        
        return true
    }
    
    
    // MAKR: - 处理 "微信、支付宝"支付完成后返回App的回调。
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.host == "safepay" {
            // 支付跳转支付宝钱包进行支付，处理支付结果
            AlipayManager.handleOpen(url)
        } else {
            // 处理微信支付的结果
            WXApi.handleOpen(url, delegate: WXApiManager.shared)
        }
        return true
    }

}

