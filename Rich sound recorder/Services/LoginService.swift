//
//  LoginService.swift
//  Rich sound recorder
//
//  Created by Marius Mathiesen on 17/03/2026.
//

import Foundation
import MSAL

struct LoginService {
    func login(){
        do {
            let authority = try MSALAADAuthority(
                url: URL(string: "https://login.microsoftonline.com/common")!
            )

            let config = MSALPublicClientApplicationConfig(
                clientId: "your-client-id",
                redirectUri: "msauth.ai.resonyx.ios-recorder://auth",
                authority: authority
            )
            let application = try MSALPublicClientApplication(configuration: config)
            print("We have come this far \(application)")

        } catch {
            print("Failed to create MSAL authority: \(error)")
        }
        
    }
}
