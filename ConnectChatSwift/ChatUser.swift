//
//  ChatUser.swift
//  ConnectChatSwift
//
//  Created by Baaye on 4/11/20.
//  Copyright © 2020 FatmaDev. All rights reserved.
//

import Foundation
import MessageKit

struct ChatUser: SenderType, Equatable {
    var senderId: String
    var displayName: String
}
