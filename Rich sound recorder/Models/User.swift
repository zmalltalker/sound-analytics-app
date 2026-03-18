//
//  User.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 18/03/2026.
//

import Foundation

struct User: Decodable {
    let oid: String
    let email: String?
    let name: String?
}
