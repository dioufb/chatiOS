import UIKit
import MessageKit

final class AppState {
  init() {
    
  }
  static let shared = AppState()
  var currentUser: [String: String]?
  var authToken : String?
  var webSocketTask: URLSessionWebSocketTask?
  var awsConfig: AWSConfigFile?
  var timer: DispatchSourceTimer?
  let primaryColor = UIColor(red: 69/255, green: 193/255, blue: 89/255, alpha: 1);
    func startHeartBeat() {
        
        let queue = DispatchQueue(label: "com.fatmadev.connect.timer")
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(deadline: .now(), repeating: .seconds(10))
        timer!.setEventHandler { [weak self] in
            self?.sendHeartBeat()
        }
        timer!.resume()
        
    }
    func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    func sendHeartBeat()  {
        self.webSocketTask?.send(URLSessionWebSocketTask.Message.string(("{\"topic\":\"aws/heartbeat\"}"))) { error in
              if let error = error {
                print("WebSocket couldn’t send message because: \(error)")
              }
        }
    }
    func sendMessage(msg : String)  {
        
        let cleanMsg = msg.escapeString()
        print("MESSAGE ===>\(cleanMsg)")
        let region = awsConfig?.CredentialsProvider.CognitoIdentity.Default.Region
        let url = "https://participant.connect.\(region!).amazonaws.com/participant/message"; 
        let obj = "{\"Content\":\"\(cleanMsg)\",\"ContentType\":\"text/plain\",\"ClientToken\":\"\(UUID().uuidString)\"}";
        self.sendPost(url: url, obj: obj)
//        return
    }
    func sendTyping()  {
        let region = awsConfig?.CredentialsProvider.CognitoIdentity.Default.Region
        let url = "https://participant.connect.\(region!).amazonaws.com/participant/event";
        let obj =
        "{\"ContentType\":\"application/vnd.amazonaws.connect.event.typing\",\"ClientToken\":\"\(UUID().uuidString)\"}"
        self.sendPost(url: url, obj: obj)
//        return
    }
    func sendDisconnect()  {
        let region = awsConfig?.CredentialsProvider.CognitoIdentity.Default.Region
        let url = "https://participant.connect.\(region!).amazonaws.com/participant/disconnect";
        let obj =
        "{\"ClientToken\":\"\(UUID().uuidString)\"}"
        self.sendPost(url: url, obj: obj)
//        return
    }
    func sendPost(url: String,obj: String)  {
        let url = URL(string: url)
        guard let requestUrl = url else { fatalError() }
        // Prepare URL Request Object
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.authToken, forHTTPHeaderField: "X-Amz-Bearer")
        // HTTP Request Parameters which will be sent in HTTP Request Body
//        let postString = "userId=300&title=My urgent task&completed=false";
        // Set HTTP Request Body
        request.httpBody = obj.data(using: String.Encoding.utf8);
        // Perform HTTP Request
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                
                // Check for Error
                if let error = error {
                    print("Error took place \(error)")
//                    return "Error took place \(error)"
                }
         
                // Convert HTTP Response Data to a String
                if let data = data, let dataString = String(data: data, encoding: .utf8) {
                    print("Response data string:\n \(dataString)")
//                    return "Response data string:\n \(dataString)"
                }
        }
        task.resume()
        
    }
    func getAvatarFor(sender: SenderType) -> Avatar {
        let firstName = sender.displayName.components(separatedBy: " ").first
        let lastName = sender.displayName.components(separatedBy: " ").first
        let initials = "\(firstName?.first ?? "?")\(lastName?.first ?? "?")"
        switch sender.senderId {
        case "000002":
            return Avatar(image: nil, initials: initials)
        case "000003":
            return Avatar(image: UIImage(named: "agent") , initials: initials)
        case "000004":
            return Avatar(image: UIImage(named: "bot"), initials: "BO")
        default:
            return Avatar(image: nil, initials: initials)
        }
    }
        struct AWSConfigFileCognitoUserPoolDefault: Decodable {
            let PoolId: String
    //        let AppClientId: String
    //        let AppClientSecret: String
            let Region: String
        }
        
        struct AWSConfigFileCognitoIdentify: Decodable {
            let Default: AWSConfigFileCognitoUserPoolDefault
        }
        struct AWSConfigFileCognitoUserPool: Decodable {
            let CognitoIdentity: AWSConfigFileCognitoIdentify
        }

        struct AWSConfigFile: Decodable {
            let CredentialsProvider: AWSConfigFileCognitoUserPool
        }
        struct ChatParticipantDetails : Decodable{
            let DisplayName: String
        }
        struct startChatWSURL: Decodable {
            let Url: String
            let ConnectionExpiry: String
        }
        struct startChatResultWebSocket : Decodable {
            let Websocket: startChatWSURL
        }
        struct chatDetails: Decodable {
            let ContactId: String
            let ParticipantId: String
            let ParticipantToken: String
        }
        struct ConnectionCredentials: Decodable {
            let ConnectionToken: String
            let Expiry: String
        }
        struct startChatResponse: Decodable {
            let ConnectionCredentials: ConnectionCredentials
            let Websocket: startChatWSURL
            let chatDetails:chatDetails
        }
    struct receivedContent: Decodable {
          let AbsoluteTime : String?
          let Content : String?
          let ContentType : String?
          let Id : String?
          let `Type`: String?
          let ParticipantId : String?
          let DisplayName : String?
          let ParticipantRole : String?
          let InitialContactId : String?
          let ContactId : String?
    }
    struct receivedPayload: Decodable {
        let content :String
        let contentType: String
        let topic : String
    }
}
extension String {
    func escapeString() -> String {
        var newString = self.replacingOccurrences(of: "\"", with: "\"\"")
        if newString.contains("\n") {
            newString = newString.replacingOccurrences(of: "\n", with: " - ")
        }
        return newString
    }
}
