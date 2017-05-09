import UIKit
import Firebase

//show the user a list of current channels


enum Section: Int {
    case createNewChannelSection = 0 //create new channel
    case currentChannelsSection //list existing channels
}

class ChannelListViewController: UITableViewController {
    var senderDisplayName: String?
    var newChannelTextField: UITextField?
    private var channels: [Channel] = []
    
    //used to store a reference to the list of channels in the database
    private lazy var channelRef: FIRDatabaseReference = FIRDatabase.database().reference().child("channels")
    //channelRefHandle will hold a handle to the reference so you can remove it later on
    private var channelRefHandle: FIRDatabaseHandle?
    
    //listen for new channels being written to the Firebase DB
    private func observeChannels() {
        // call observe:with: on your channel reference, storing a handle to the reference. This calls the completion block every time a new channel is added to your database
        channelRefHandle = channelRef.observe(.childAdded, with: { (snapshot) -> Void in
            //The completion receives a FIRDataSnapshot (stored in snapshot), which contains the data and other helpful methods.
            let channelData = snapshot.value as! Dictionary<String, AnyObject>
            let id = snapshot.key
            
            //create a Channel model and add it to your channels array
            if let name = channelData["name"] as! String!, name.characters.count > 0 {
                self.channels.append(Channel(id: id, name: name))
                self.tableView.reloadData()
            } else {
                print("Error! Could not decode channel data")
            }
        })
    }
    
    //calls observeChannels() method when the view controller loads
    //receive update after creation of new channel
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "RW RIC"
        observeChannels()
    }
    
    deinit {
        if let refHandle = channelRefHandle {
            // stop observing database changes when the view controller dies
            channelRef.removeObserver(withHandle: refHandle)
        }
    }
    
    @IBAction func createChannel(_ sender: AnyObject) {
        if let name = newChannelTextField?.text {
            let newChannelRef = channelRef.childByAutoId()
            
            //JSON like String item
            let channelItem = [ // 3
                "name": name
            ]
            
            //set new name
            newChannelRef.setValue(channelItem) // 4
        }
    }
    
    //2 sections: create new channel + list existing ones
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    //assign number of required rows to sections
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { // 2
        if let currentSection: Section = Section(rawValue: section) {
            switch currentSection {
                
            //1 row for channel creation
            case .createNewChannelSection:
                return 1
                
            //1 row for each channel
            case .currentChannelsSection:
                return channels.count
            }
        } else {
            return 0
        }
    }
    
    //set view of the 2 sections
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reuseIdentifier = (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue ? "NewChannel" : "ExistingChannel"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
    
        if (indexPath as NSIndexPath).section == Section.createNewChannelSection.rawValue {
            
            //store the text field from the cell in newChannelTextField property
            if let createNewChannelCell = cell as? CreateChannelCell {
                newChannelTextField = createNewChannelCell.newChannelNameField
            }
        } else if (indexPath as NSIndexPath).section == Section.currentChannelsSection.rawValue {
            //set the cell’s text label as channel name
            cell.textLabel?.text = channels[(indexPath as NSIndexPath).row].name
        }
        
        return cell
    }
    
    //open selected table view on user input
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == Section.currentChannelsSection.rawValue {
            let channel = channels[(indexPath as NSIndexPath).row]
            self.performSegue(withIdentifier: "ShowChannel", sender: channel)
        }
    }
    
    //navigation
    //set up the properties on the ChatViewController that were created before performing the segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let channel = sender as? Channel {
            let chatVc = segue.destination as! ChatViewController
            
            chatVc.senderDisplayName = senderDisplayName
            chatVc.channel = channel
            chatVc.channelRef = channelRef.child(channel.id)
        }
    }
}
