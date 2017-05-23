import UIKit
import Firebase
import JSQMessagesViewController
import AVFoundation
import Foundation
import CoreMotion

//inherit from JSQMessagesViewController to get the chat UI
final class ChatViewController: JSQMessagesViewController {
    
    //Properties
    let captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()
    var previewLayer : AVCaptureVideoPreviewLayer?
    
    let manager = CMMotionManager()
    
    // If we find a device we'll store it here for later use
    var captureDevice : AVCaptureDevice?
    
    var messages = [JSQMessage]() //array to store the various instances of JSQMessage
    
    lazy var outgoingBubbleImageView: JSQMessagesBubbleImage = self.setupOutgoingBubble()
    lazy var incomingBubbleImageView: JSQMessagesBubbleImage = self.setupIncomingBubble()
    
    private lazy var messageRef: FIRDatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: FIRDatabaseHandle?
    
    //Create a Firebase reference that tracks whether the local user is typing
    private lazy var userIsTypingRef: FIRDatabaseReference = self.channelRef!.child("typingIndicator").child(self.senderId)
    private var localTyping = false
    var isTyping: Bool {
        get {
            return localTyping
        }
        set {
            localTyping = newValue
            userIsTypingRef.setValue(newValue)
        }
    }
    
    //retrieve all of the users that are currently typing
    private lazy var usersTypingQuery: FIRDatabaseQuery = self.channelRef!.child("typingIndicator").queryOrderedByValue().queryEqual(toValue: true)
    
    var channelRef: FIRDatabaseReference?
    var channel: Channel? {
        didSet {
            title = channel?.name
        }
    }
    
    //Database
    let URL_SAVE_TEAM = "http://la-webtest.de/mob/webservice/api/createteam.php"
    
    // END properties
     
    override func viewDidLoad() {
        super.viewDidLoad()
        self.senderId = FIRAuth.auth()?.currentUser?.uid

        //camera setup
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if let devices = AVCaptureDevice.devices() as? [AVCaptureDevice] {
            // Loop through all the capture devices on this phone
            for device in devices {
                // Make sure this particular device supports video
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    // Finally check the position and confirm we've got the back camera
                    if(device.position == AVCaptureDevicePosition.back) {
                        captureDevice = device
                        if captureDevice != nil {
                            print("Capture device found")
                            beginSession()
                        }
                    }
                }
            }
        }

        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        // Collection view style
        self.collectionView.backgroundColor = UIColor.clear

        logGyro()
        DBpost(name: "lukas", time: 0.1, gyrox: 0.223)
        
        observeMessages()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        observeTyping()
    }
    
    // Collection view data source (and related) methods
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    //POST to WebService
    func DBpost(name: String, time: Double, gyrox: Double) {
        //created NSURL
        let requestURL = NSURL(string: URL_SAVE_TEAM)
        let request = NSMutableURLRequest(url: requestURL! as URL)
        request.httpMethod = "POST"
        
        //hard coded input
        let postParameters = "condition=ConditionA&name=" + name + "&time=" + String(time) + "&gyrox=" + String(gyrox)
        
        request.httpBody = postParameters.data(using: String.Encoding.utf8)
        
        //creating a task to send the post request
        let task = URLSession.shared.dataTask(with: request as URLRequest){
            data, response, error in
            
            if error != nil{
                print("error is \(error)")
                return;
            }
            
            //parsing the response
            do {
                //converting resonse to NSDictionary
                let myJSON =  try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as? NSDictionary
                
                //parsing the json
                if let parseJSON = myJSON {
                    
                    //creating a string
                    var msg : String!
                    
                    //getting the json response
                    msg = parseJSON["message"] as! String?
                    
                    //printing the response
                    print(msg)
                    
                }
            } catch {
                print(error)
            }
            
        }
        //executing the task
        task.resume()
    }
    
    //measures pitch value in degree
    func logGyro() {
        if manager.isGyroAvailable {
            if manager.isDeviceMotionAvailable {
                manager.deviceMotionUpdateInterval = 1.00
                manager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler:{
                    data, error in
                    if let attitude = data?.attitude {
                        let attitudeX = attitude.quaternion.x
                        let attitudeY = attitude.quaternion.y
                        let attitudeZ = attitude.quaternion.z
                        let attitudeW = attitude.quaternion.w
                        
                        let pitchRadian = atan2(2*attitudeX * attitudeW + 2*attitudeY * attitudeZ, 1 - 2*attitudeX * attitudeX - 2*attitudeZ * attitudeZ)
                        let pitchDegree = round(1000 * (pitchRadian * 180.0/Double.pi))/1000
                        
                        print("PitchDegree: \(pitchDegree)")
                    }
                })
            }
        }
    }
    
    //camera setup
    func beginSession() {
        
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
            stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
            
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            }
            
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        
        guard let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) else {
            print("no preview layer")
            return
        }
        
        self.view.layer.insertSublayer(previewLayer, at:0)
        previewLayer.frame = self.view.layer.frame
        captureSession.startRunning()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // UI and User Interaction
    //Bubbles of outgoing messages
    private func setupOutgoingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory(bubble: UIImage.jsq_bubbleRegularStroked(), capInsets: .zero)
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue().withAlphaComponent(CGFloat(0.7)))
    }
    
    //Bubbles of incoming messages
    private func setupIncomingBubble() -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory(bubble: UIImage.jsq_bubbleRegularStroked(), capInsets: .zero)
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray().withAlphaComponent(CGFloat(0.5)))
    }
    
    //Remove avatars
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    //change text color of incoming messages to black
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        
        if message.senderId == senderId {
            cell.textView?.layer.borderColor = UIColor.clear.cgColor
            cell.textView?.textColor = UIColor.white
            cell.textView?.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(0.3))

        } else {
            cell.textView?.layer.borderColor = UIColor.clear.cgColor
            cell.textView?.textColor = UIColor.white
            cell.textView?.backgroundColor = UIColor.black.withAlphaComponent(CGFloat(0.3))
        }

        cell.textView?.layer.cornerRadius = 19
        cell.textView?.layer.borderWidth = 1
        return cell
    }
    
    //Add message: create a new JSQMessage and add it to the data source
    private func addMessage(withId id: String, name: String, text: String) {
        if let message = JSQMessage(senderId: id, displayName: name, text: text) {
            messages.append(message)
        }
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": text!,
            ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        isTyping = false //reset typing indicator when message is sent
    }
    
    //display messages -> call addMessage when .ChildAdded event occurs
    private func observeMessages() {
        messageRef = channelRef!.child("messages")
        
        let messageQuery = messageRef.queryLimited(toLast:25)
        
        // Use the .ChildAdded event to observe for every child item that has been added, and will be added
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            
            let messageData = snapshot.value as! Dictionary<String, String>
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.characters.count > 0 {
                
                self.addMessage(withId: id, name: name, text: text)
                
                // inform JSQMessagesViewController that a message has been received
                self.finishReceivingMessage()
            } else {
                print("Error! Could not decode message data")
            }
        })
    }
    
    //other user is typing
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
        isTyping = textView.text != ""
    }
    
    private func observeTyping() {
        let typingIndicatorRef = channelRef!.child("typingIndicator")
        userIsTypingRef = typingIndicatorRef.child(senderId)
        userIsTypingRef.onDisconnectRemoveValue()
        
        //observe for changes using .value
        usersTypingQuery.observe(.value) { (data: FIRDataSnapshot) in
            
            //If the there’s just one user and that’s the local user, don’t display the indicator
            if data.childrenCount == 1 && self.isTyping {
                return
            }
            
            self.showTypingIndicator = data.childrenCount > 0
            self.scrollToBottom(animated: true)
        }
    }
    
    // UITextViewDelegate methods
    // asks the data source for the message bubble image data that corresponds to the message item at indexPath in the collectionView
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        
        //retrieve message
        let message = messages[indexPath.item]
        
        //If the message was sent by the local user, return the outgoing image view
        if message.senderId == senderId {
            return outgoingBubbleImageView
        } else {
            return incomingBubbleImageView
        }
    }
    
}
