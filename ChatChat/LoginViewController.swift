import UIKit
import Firebase

var userName : String = String()

class LoginViewController: UIViewController {
  
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var bottomLayoutGuideConstraint: NSLayoutConstraint!
  
    
    // MARK: View Lifecycle
  
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillShowNotification(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHideNotification(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
  
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
  
    @IBAction func loginDidTouch(_ sender: AnyObject) {
        //check if name field isn’t empty
        if nameField?.text != "" {
    
            //use the Firebase Auth API to sign in anonymously
            FIRAuth.auth()?.signInAnonymously(completion: { (user, error) in
                if let err = error {
                    print(err.localizedDescription)
                    return
                }
                
                userName = self.nameField.text!
                
                //if there wasn’t an error, trigger the segue to move to the ChannelListViewController
                self.performSegue(withIdentifier: "LoginToChat", sender: nil)
            })
        }
    }
  
    // Notifications
    func keyboardWillShowNotification(_ notification: Notification) {
        let keyboardEndFrame = ((notification as NSNotification).userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        let convertedKeyboardEndFrame = view.convert(keyboardEndFrame, from: view.window)
        bottomLayoutGuideConstraint.constant = view.bounds.maxY - convertedKeyboardEndFrame.minY
    }
  
    func keyboardWillHideNotification(_ notification: Notification) {
        bottomLayoutGuideConstraint.constant = 48
    }
    
    //get userName and set it for ChannelListViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        //retrieve the destination view controller from segue and cast it to a UINavigationController
        let navVc = segue.destination as! UINavigationController
        
        //Cast the first view controller of the UINavigationController to a ChannelListViewController
        let channelVc = navVc.viewControllers.first as! ChannelListViewController
        
        //set senderDisplayName in ChannelListViewController to the name provided by the user
        channelVc.senderDisplayName = nameField?.text // 3
    }
}

