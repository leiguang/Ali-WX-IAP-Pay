//
//  IAPStatus.swift
//  雅思哥
//
//  Created by 雷广 on 2017/12/22.
//  Copyright © 2017年 chutzpah. All rights reserved.
//

import Foundation

/// IAP 支付购买状态
enum IAPStatus {
    
    /*    --------  1.能否支付  --------    */
    /// 用户禁止应用内付费购买
    case unableToPay
    
    /*    --------  2.支付之前验证hcp支付订单  --------    */
    /// 支付之前去服务器创建一个订单
    case createOrderBeforePayStart
    /// 创建订单成功
    case createOrderBeforePaySuccess
    /// 创建订单失败
    case createOrderBeforePayFailed(String)
    
    /*    --------  3.验证获取产品信息 的请求状态  --------    */
    /// 开始获取产品信息
    case productRequestStart
    /// 获取验证产品信息成功
    case productRequestSuccess
    /// 获取验证产品信息失败
    case productRequestFailed(String)
    
    /*    --------  4.支付状态  --------    */
    /// 请求支付中...
    case purchasing
    /// 如小孩购买，尚无权限，需等待家人给权限
    case deferred
    /// 已购商品，恢复购买
    case restored
    /// 购买成功 (接下来还要去服务器验证购买凭据)
    case purchased
    /// 支付失败
    case paymentFailed(String)
    /// 用户取消支付
    case paymentCancelled
    
    /*    --------  5.向hcp服务器验证购买凭证的状态  --------    */
    /// 正在向服务器验证购买凭证的有效性...
    case receiptValidateStart
    /// 凭证验证失败
    case receiptValidationFailed(String)
    /// 凭证验证成功，发放购买内容，刷新页面
    case receiptValidationSuccess
    
}

extension IAPStatus {
    /// 支付是否成功
    var isSuccess: Bool {
        switch self {
        case .receiptValidationSuccess:
            return true
        default:
            return false
        }
    }
    
    /// 支付是否失败 （注意: 除成功、失败的状态外，还有支付进行中的状态）
    var isFailed: Bool {
        switch self {
        case .createOrderBeforePayFailed,
             .productRequestFailed,
             .paymentFailed,
             .receiptValidationFailed:
            return true
        default:
            return false
        }
    }
}

