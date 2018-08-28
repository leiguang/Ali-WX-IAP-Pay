//
//  IAPPayKnowPopupView.swift
//  雅思哥
//
//  Created by 雷广 on 2018/1/5.
//  Copyright © 2018年 chutzpah. All rights reserved.
//

import UIKit

class IAPPayKnowPopupView: UIView {
    
    @IBOutlet weak var label: UILabel!
    
    var knowHandler: (()->Void)? = nil
    
    func show() {
        UIApplication.shared.keyWindow!.addSubview(self)
    }
    
    @IBAction private func knowAction(_ sender: Any) {
        if knowHandler != nil { knowHandler!() }
        removeFromSuperview()
    }
    
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        initialFromXib()
//    }
    
    init(text: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight))
        initialFromXib()
        
        let attrs = String.attributesWith(font: UIFont.systemFont(ofSize: 16), color: Color.textBlack, characterSpace: 0.0, lineSpace: 6.0)
        label.attributedText = NSAttributedString(string: text, attributes: attrs)
    }
    
    init(attrsText: NSAttributedString) {
        super.init(frame: CGRect(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight))
        initialFromXib()
        
        label.attributedText = attrsText
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initialFromXib() {
        let nib = UINib(nibName: "IAPPayKnowPopupView", bundle: nil)
        let contentView = nib.instantiate(withOwner: self, options: nil).first! as! UIView
        contentView.frame = bounds
        addSubview(contentView)
    }
}
