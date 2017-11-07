//
//  UIView+AutoLayout.swift
//  Demo-Swift
//
//  Created by Peter Edmonston on 9/18/17.
//

import UIKit

extension UIView {
    func addSubview(_ subview: UIView, insets: UIEdgeInsets) {
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        subview.topAnchor.constraint(equalTo: topAnchor, constant: insets.top).isActive = true
        subview.bottomAnchor.constraint(equalTo: bottomAnchor, constant: insets.bottom).isActive = true
        subview.leftAnchor.constraint(equalTo: leftAnchor, constant: insets.left).isActive = true
        subview.rightAnchor.constraint(equalTo: rightAnchor, constant: insets.right).isActive = true
    }
    
    func setFixedSize(_ size: CGSize) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size.width).isActive = true
        heightAnchor.constraint(equalToConstant: size.height).isActive = true
    }
}
