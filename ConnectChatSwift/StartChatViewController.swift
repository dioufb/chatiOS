//
//  StartChatViewController.swift
//  ConnectChatSwift
//
//  Created by Baaye on 4/12/20.
//  Copyright © 2020 FatmaDev. All rights reserved.
//

import Foundation



class StartChatViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Click below to start a new chat session", baseColor: UIColor.white)
    }
    
    @IBAction func startNewChat() {
        AppState.shared.authToken = nil;
        AppState.shared.webSocketTask = nil;
        AppState.shared.awsConfig = nil;
        AppState.shared.stopTimer()
        AppState.shared.timer = nil;
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let secondVC = storyboard.instantiateViewController(identifier: "ViewController")
        
        self.navigationController?.pushViewController(secondVC, animated:true);
        

    }
}
