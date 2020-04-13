//
//  ViewController.swift
//  ConnectChatSwift
//
//  Created by Bamba on 4/11/20.
//
//TODO: Handle when app goes to background mode
//TODO: Handle no heartbeat received
//TODO: StatusBar Color
//TODO: Create a settings page
//TODO: connect to Lex


import Foundation
import UIKit
import AWSMobileClient
import AWSAuthUI
import MessageKit
import Amplify



final class ViewController: ChatViewController, URLSessionWebSocketDelegate {
//    var webSocketTask : URLSessionWebSocketTask = any as! URLSessionWebSocketTask;
    override func viewDidLoad() { 
        super.viewDidLoad()
        title = ""
        let close = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        
        navigationItem.rightBarButtonItems = [close]
        
        navigationController?.navigationBar.prefersLargeTitles = true
        
        AWSMobileClient.default().initialize { (userState, error) in
            if let userState = userState {
                switch(userState){
                case .signedIn:
                    self.configureChatView()
                case .signedOut:
                    AWSMobileClient.default().signOut()
                    AWSMobileClient.default().showSignIn(navigationController: self.navigationController!, signInUIOptions: SignInUIOptions(
                            canCancel: false,
                            logoImage: UIImage(named: "connect"),
                             backgroundColor: UIColor.white), { (userState, error) in
                        if(error == nil){       //Successful signin
                            self.configureChatView()
                        }
                    })
                default:
                    if (AWSMobileClient.default().isSignedIn==false) {
                        AWSMobileClient.default().showSignIn(navigationController: self.navigationController!, signInUIOptions: SignInUIOptions(
                                canCancel: false,
                                logoImage: UIImage(named: "connect"),
                                 backgroundColor: UIColor.white), { (userState, error) in
                            if(error == nil){       //Successful signin
                                self.configureChatView()
                            }
                        })
                    } else {
                       self.configureChatView()
                    }

                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc func closeTapped() {
        AppState.shared.sendDisconnect();
        AppState.shared.authToken = nil;
        AppState.shared.webSocketTask = nil;
        AppState.shared.awsConfig = nil;
        AppState.shared.stopTimer()
        AppState.shared.timer = nil;
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let secondVC = storyboard.instantiateViewController(identifier: "StartChatViewController")
        self.navigationController?.setViewControllers([secondVC], animated: true)
    }
    func showResult(task: AWSTask<AnyObject>) {
        if let error = task.error {
            print("Error: \(error)")
        } else if let result = task.result {
            if result is CONNECTCHATIOSResponseSchema {
                let res = result as! CONNECTCHATIOSResponseSchema
            } else if result is NSDictionary {
                let res = result as! NSDictionary
                
                let jsonString = (res["data"] as! NSDictionary)["body"] as! String
//                print(jsonString)
                let chatResponse: AppState.startChatResponse =  try! JSONDecoder().decode(AppState.startChatResponse.self, from: jsonString.data(using: .utf8)!)

                let urlSession = URLSession(configuration: .default, delegate: self,delegateQueue: OperationQueue())

                let webSocketTask = urlSession.webSocketTask(with: URL(string: chatResponse.Websocket.Url)!,protocols: ["chat"] );
                AppState.shared.webSocketTask = webSocketTask;
                AppState.shared.authToken = chatResponse.ConnectionCredentials.ConnectionToken
                
                receiveMessage();
                webSocketTask.resume()
                webSocketTask.send(URLSessionWebSocketTask.Message.string(("{\"topic\":\"aws/subscribe\",\"content\":{\"topics\":[\"aws/chat\"]}}"))) { error in
                      if let error = error {
                        print("WebSocket couldn’t send message because: \(error)")
                      }
                }
            }
        }
    }
    func receiveMessage() {
        if (AppState.shared.webSocketTask==nil) {
            return;
        }
      AppState.shared.webSocketTask!.receive { result in
        switch result {
            case .failure(let error):
              print("Error in receiving message: \(error)")
            case .success(let message):
              switch message {
                  case .string(let text):
//                    print("Received string: \(text)")
                    self.displayMessage(mess: text)
                  case .data(let data):
                    print("Received data: \(data)")
                  default:
                    print("Received data: \(message)")
              }
              
              self.receiveMessage()
        }
      }
    }
    func displayMessage(mess: String) {
        
        if (mess.contains("aws/subscribe")) {
            AppState.shared.startHeartBeat()
            return
        }
        if (mess.contains("aws/heartbeat")) {
            //TODO: Add logic to dectect stale connection
            return
        }
        if (!mess.contains("aws/chat")) {
//            print(mess)
            return
        }
        let messObjWrapper : AppState.receivedPayload = try! JSONDecoder().decode(AppState.receivedPayload.self, from: mess.data(using: .utf8)!)
        
        let messObj : AppState.receivedContent = try! JSONDecoder().decode(AppState.receivedContent.self, from: messObjWrapper.content.data(using: .utf8)!)
        
        switch messObj.ContentType {
        case "text/plain":
            switch messObj.ParticipantRole {
                case "CUSTOMER":
                    let user = ChatUser(senderId: "000002", displayName: messObj.DisplayName!)
                    let message = ChatMessage(text: messObj.Content!, user: user, messageId: UUID().uuidString, date: Date())
                    DispatchQueue.main.async {
                        self.insertMessage(message)
                    }
                case "AGENT":
                    let user = ChatUser(senderId: "000003", displayName: messObj.DisplayName!)
                    let message = ChatMessage(text: messObj.Content!, user: user, messageId: UUID().uuidString, date: Date())
                    DispatchQueue.main.async {
                        self.setTypingIndicatorViewHidden(true, performUpdates: {
                                self.insertMessage(message)
                        })
                    }
                    DispatchQueue.main.async {
                        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Chatting with \(messObj.DisplayName!)", baseColor: UIColor.white)
                    }
                case "SYSTEM":
                    let user = ChatUser(senderId: "000004", displayName: messObj.DisplayName!)
                    let message = ChatMessage(text: messObj.Content!, user: user, messageId: UUID().uuidString, date: Date())
                    DispatchQueue.main.async {
                        self.insertMessage(message)
                        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Chatting with Buddy(Virtual)", baseColor: UIColor.white)
                    }

                default:
                    print ("Unsupported :=======> \(messObj.ParticipantRole)")
            }
        default:
            switch messObj.ContentType {
                case "application/vnd.amazonaws.connect.event.participant.joined":
                    DispatchQueue.main.async {
                        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Agent \(messObj.DisplayName!) has joined the Chat session", baseColor: UIColor.white)
                    }
                case "application/vnd.amazonaws.connect.event.participant.left":
                    DispatchQueue.main.async {
                        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "\(messObj.DisplayName!) has left the Chat session", baseColor: UIColor.white)
                    }
                case "application/vnd.amazonaws.connect.event.chat.ended":
                    DispatchQueue.main.async {
                        self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Chat session ended", baseColor: UIColor.white)
                    }
                case "application/vnd.amazonaws.connect.event.typing":
                    if (messObj.ParticipantRole=="AGENT") {
                        DispatchQueue.main.async {
                            self.setTypingIndicatorViewHidden(false);
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { // Change `2.0` to the desired number of
                            DispatchQueue.main.async {
                                self.setTypingIndicatorViewHidden(true, performUpdates: {
                                    self.updateTitleView(title: "Amazon Connect Chat", subtitle: "Conversation with \(messObj.DisplayName!)", baseColor: UIColor.white)
                                })
                            }
                        }
                    }
                default:
                    print ("Unsupported :=======> \(messObj.ParticipantRole)")
            }
        }
        

    }
    func setTypingIndicatorViewHidden(_ isHidden: Bool, performUpdates updates: (() -> Void)? = nil) {
        updateTitleView(title: "Amazon Connect Chat", subtitle: "Typing...", baseColor: UIColor.white)
        setTypingIndicatorViewHidden(isHidden, animated: true, whilePerforming: updates) { [weak self] success in
//            print(success)
            if success, self?.isLastSectionVisible() == true {
                self?.messagesCollectionView.scrollToBottom(animated: true)
            }
            if !success, isHidden == true {
                updates?()
            }
        }
    }
    func configureChatView() {
//        title = "Amazon Connect Chat"
        updateTitleView(title: "Amazon Connect Chat", subtitle: "Chatting with Buddy(Virtual)", baseColor: UIColor.white)

        
        if let filepath = Bundle.main.path(forResource: "awsconfiguration", ofType: "json") {
            do {
                let contents = try String(contentsOfFile: filepath)
                
                let awsConfigFile: AppState.AWSConfigFile = try! JSONDecoder().decode(AppState.AWSConfigFile.self, from: contents.data(using: .utf8)!)
                AppState.shared.awsConfig = awsConfigFile;
                
                let credentialsProvider = AWSCognitoCredentialsProvider(regionType: AWSRegionType.USEast1, identityPoolId: awsConfigFile.CredentialsProvider.CognitoIdentity.Default.PoolId)
                let configuration = AWSServiceConfiguration(region: AWSRegionType.USEast1, credentialsProvider: credentialsProvider)
                AWSServiceManager.default().defaultServiceConfiguration = configuration
                let client = CONNECTCHATIOSConnectChatiOSClient.default()
                
                
                let body: CONNECTCHATIOSRequestSchema = CONNECTCHATIOSRequestSchema(request: "{\"DisplayName\":\"Bamba Diouf\",\"InstanceId\":\"5e6085d9-44ac-4706-bbf0-78798a4e92ec\",\"ContactFlowId\":\"6b3a6129-4882-47b9-b843-c218150e2ce5\",\"Attributes\":{\"DisplayName\":\"DisplayName\"},\"ParticipantDetails\":{\"DisplayName\":\"DisplayName\"}}");
               
                client.startChatOptions(_body: body ).continueWith {(task: AWSTask) -> AnyObject? in
                    self.showResult(task: task)
                    return nil 
                }    
            } catch {
                // contents could not be loaded
            }
        } else {
            // example.txt not found!
        }
         
    }
    
    override func configureMessageCollectionView() {
        super.configureMessageCollectionView()
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        self.setupCollectionView()
        self.inputStyle()
    }
    private func setupCollectionView() {
            guard let flowLayout = messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout else {
                print("Can't get flowLayout")
                return
            }
            
            flowLayout.collectionView?.backgroundColor = UIColor.white
        var navigationBarAppearace = UINavigationBar.appearance()

//        navigationBarAppearace.tintColor = UIColor.black ;//UIColor(red: 245, green: 245, blue: 255, alpha: 255)
//        navigationBarAppearace.barTintColor = UIColor (red: 245, green: 245, blue: 255, alpha: 255)
        navigationBarAppearace.tintColor = UIColor(red: 255, green: 255, blue: 255, alpha: 255);//UIColor(red: 245, green: 245, blue: 255, alpha: 255)3,69,23
        navigationBarAppearace.barTintColor = UIColor (red: 3, green: 69, blue: 23, alpha: 255)

//        navigationBarAppearace.tintColor = UIColor(red: 255, green: 255, blue: 255, alpha: 255)
//        navigationBarAppearace.barTintColor = UIColor(red: 255, green: 255, blue: 255, alpha: 255)
        // change navigation item title color
        navigationBarAppearace.titleTextAttributes = [NSAttributedString.Key.foregroundColor :UIColor.white,NSAttributedString.Key.font: UIFont(name: "HelveticaNeue-CondensedBlack", size: 40)!]

    }
    func inputStyle() {
//            if #available(iOS 13.0, *) {
//                messageInputBar.inputTextView.textColor = .label
//                messageInputBar.inputTextView.placeholderLabel.textColor = .secondaryLabel
//                messageInputBar.backgroundView.backgroundColor = .systemBackground
//            } else {
                messageInputBar.inputTextView.textColor = .black
                messageInputBar.inputTextView.backgroundColor = UIColor(red: 245, green: 245, blue: 245, alpha: 255)
                messageInputBar.backgroundView.backgroundColor = UIColor(red: 245, green: 245, blue: 255, alpha: 255)
//            }
    }
} 

// MARK: - MessagesDisplayDelegate

extension ViewController: MessagesDisplayDelegate {
    
    // MARK: - Text Messages
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    func detectorAttributes(for detector: DetectorType, and message: MessageType, at indexPath: IndexPath) -> [NSAttributedString.Key: Any] {
        switch detector {
        case .hashtag, .mention: return [.foregroundColor: UIColor.blue]
        default: return MessageLabel.defaultAttributes
        }
    }
    
    func enabledDetectors(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> [DetectorType] {
        return [.url, .address, .phoneNumber, .date, .transitInformation, .mention, .hashtag]
    }
    
    // MARK: - All Messages
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? AppState.shared.primaryColor : UIColor(red: 230/255, green: 230/255, blue: 230/255, alpha: 1)
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        
        let tail: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(tail, .curved)
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let avatar = AppState.shared.getAvatarFor(sender: message.sender)
        avatarView.set(avatar: avatar)
    }

    open class StartChatRequest: AWSModel
    {
        open var DisplayName :  String? = nil
        open var InstanceId : String? = nil
        open var ContactFlowId : String? = nil
        open var Attributes: [String: String]? = [:]
        
        open var ParticipantDetails: [String: String]? = [:]

        public convenience init!(_DisplayName: String,_InstanceId: String,_ContactFlowId: String) {
            self.init()
            self.DisplayName = _DisplayName;
            self.InstanceId = _InstanceId;
            self.ContactFlowId = _ContactFlowId
            self.Attributes = [
                "DisplayName":_DisplayName
            ]
            self.ParticipantDetails = [
                "DisplayName":_DisplayName
            ]
        }
        
        override open class func jsonKeyPathsByPropertyKey() -> [AnyHashable: Any]!
        {
            return [:]
        }
    }
    
    // MARK: - Location Messages
    
//    func annotationViewForLocation(message: MessageType, at indexPath: IndexPath, in messageCollectionView: MessagesCollectionView) -> MKAnnotationView? {
//        let annotationView = MKAnnotationView(annotation: nil, reuseIdentifier: nil)
//        let pinImage = #imageLiteral(resourceName: "ic_map_marker")
//        annotationView.image = pinImage
//        annotationView.centerOffset = CGPoint(x: 0, y: -pinImage.size.height / 2)
//        return annotationView
//    }
    
//    func animationBlockForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> ((UIImageView) -> Void)? {
//        return { view in
//            view.layer.transform = CATransform3DMakeScale(2, 2, 2)
//            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0, options: [], animations: {
//                view.layer.transform = CATransform3DIdentity
//            }, completion: nil)
//        }
//    }
//
//    func snapshotOptionsForLocation(message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> LocationMessageSnapshotOptions {
//
//        return LocationMessageSnapshotOptions(showsBuildings: true, showsPointsOfInterest: true, span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
//    }
//
//    // MARK: - Audio Messages
//
//    func audioTintColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
//        return isFromCurrentSender(message: message) ? .white : UIColor(red: 15/255, green: 135/255, blue: 255/255, alpha: 1.0)
//    }
//
//    func configureAudioCell(_ cell: AudioMessageCell, message: MessageType) {
//        audioController.configureAudioCell(cell, message: message) // this is needed especily when the cell is reconfigure while is playing sound
//    }

}

// MARK: - MessagesLayoutDelegate

extension ViewController: MessagesLayoutDelegate {
    
    func cellTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 18
    }
    
    func cellBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 1
    }
    
    func messageTopLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 1
    }
    
    func messageBottomLabelHeight(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> CGFloat {
        return 1
    }
    
}




