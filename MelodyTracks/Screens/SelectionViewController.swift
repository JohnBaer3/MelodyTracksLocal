//
//  SelectionViewController.swift
//  MelodyTracks
//
//  Created by Daniel Loi on 7/6/20.
//  Copyright © 2020 Daniel Loi. All rights reserved.
//

import UIKit
import MediaPlayer
import CoreData
import CoreServices

import AVKit


//stuff from AVAudioPlayer port
//var paused = true  //moved to Custom Curtain View
//var SongsArr: [Song] = [] //moved to Custom Curtain View
//var currentSong: Song? = nil //declared in Custom Curtain View
//var currentSongIndex: Int? = nil //declared in Custom Curtain View
//var previousSongs: [Song] = [] //declared in Custom Curtain View
//let audioPlayer = AVAudioPlayerNode()



//Passed into SongLibraryScreen and CustomCurtainController
var SongsArr : [Song] = []

let audioPlayer = AVAudioEngine()


var chosenMPH = 0

//gets passed to next screen to determine if manual mode or smart mode
var manualSmart = false



class SelectionViewController: UIViewController, MPMediaPickerControllerDelegate {
    @IBOutlet weak var MPH: UILabel!
    @IBOutlet weak var saveButton: selectSongButton!
    @IBOutlet weak var walkButton: UIButton!
    @IBOutlet weak var jogButton: UIButton!
    @IBOutlet weak var runButton: UIButton!
    @IBOutlet weak var fixedButton: selectorButton!
    @IBOutlet weak var autoButton: selectorButton!
    @IBOutlet weak var descriptionText: UILabel!
    @IBOutlet weak var walkJogRunStack: UIStackView!
    @IBOutlet weak var mphStack: UIStackView!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var songsData: [SongsDataModel]?
    
    
    // set notification name
    static let showFinishNotification = Notification.Name("showFinishNotification")
    static let TimerNotification = Notification.Name("TimerNotification")
        
    //stuff from AVAudioPlayer port
    //var engine : AVAudioEngine!
    let engine = AVAudioEngine()
    let speedControl = AVAudioUnitVarispeed()
    let pitchControl = AVAudioUnitTimePitch()

    let engineBPM = AVAudioEngine()
    //var engineBPM : AVAudioEngine!
    let speedControlBPM = AVAudioUnitVarispeed()
    let pitchControlBPM = AVAudioUnitTimePitch()
    
    var speedOfBPM:Float = 0.0
    //stuff from AVAudioPlayer port
    
    //var audioPlayer = MPMusicPlayerController.systemMusicPlayer
    let audioPlayer = AVAudioPlayerNode()
    //var audioPlayer : AVAudioPlayerNode!
    let picker = MPMediaPickerController(mediaTypes:MPMediaType.anyAudio)
    var trackList : MPMediaItemCollection?
    var hideFinishButton: Bool!
    
    var higherBoundMPH = 15
    var lowerBoundMPH = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let songData: [SongsDataModel]?
        
        
        
        let songTestURL = "file:///private/var/mobile/Containers/Data/Application/83A5DC9C-7E61-4E7D-9317-4DF3A2449B5C/tmp/com.CSE115A.MelodyTracks-Inbox/Mac%20Miller%20-%20My%20Favorite%20Part%20(feat.%20Ariana%20Grande).mp3"
        
        //removeSuffix
        
        
        saveButton.setInitialDetails()
        setInitialMPH()
//        getBPMofSongs()
        
        //check to see if there is current audio playing
        if audioPlayer.isPlaying == true {
            audioPlayer.pause()
        }
        fixedAutoSwap(tapped: fixedButton, other: autoButton)
        walkButton.layer.cornerRadius = 10
        jogButton.layer.cornerRadius = 10
        runButton.layer.cornerRadius = 10
        
        chosenMPH = Int(MPH.text!)!
    }
    
    
    func play(_ url: URL) throws {
        print("runs special play")
        // 1: load the file
        let file = try AVAudioFile(forReading: url)


        // 3: connect the components to our playback engine
        engine.attach(audioPlayer ?? AVAudioPlayerNode())
        engine.attach(pitchControl)
        engine.attach(speedControl)
        
        // 4: arrange the parts so that output from one is input to another
        engine.connect(audioPlayer ?? AVAudioPlayerNode(), to: speedControl, format: nil)
        engine.connect(speedControl, to: pitchControl, format: nil)
        engine.connect(pitchControl, to: engine.mainMixerNode, format: nil)

        // 5: prepare the player to play its file from the beginning
        audioPlayer.scheduleFile(file, at: nil)
        
        // 6: start the engine and player
        try engine.start()
        do {
           try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch(let error) {
            print(error.localizedDescription)
        }
        audioPlayer.play()
    }
    
    
    //Deltes all core data of entityName
    func deleteCoreData(){
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SongsDataModel")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
        } catch let error as NSError {
            // TODO: handle the error
        }
    }
    
    
    
    /**
     * Method name: getBPMofSongs()
     * Description: used to get BPM of the songs in the user's library
     * Parameters: N/A
     */
    func getBPMofSongs(){
        let fm = FileManager.default
        let filePath = Bundle.main.path(forAuxiliaryExecutable: "Songs")
        let songs = try! fm.contentsOfDirectory(atPath: filePath!)
        for song in songs{
            let title =  removeSuffix(songURL: song)
            let filePathSong = Bundle.main.path(forResource: title, ofType: "mp3", inDirectory: "Songs")
            let songUrl = URL(string: filePathSong!)
            
            
            let BPMOfSong = BPMAnalyzer.core.getBpmFrom(songUrl!, completion: nil)
            let newSong = Song(title: title, BPM: convertBPMToFloat(BPMOfSong), played: false)
            
//            let newSong = Song(title: title, BPM: 100.0, played: false)
            SongsArr.append(newSong)
        }
    }
    /**
     * Method name: convertBPMToFloat
     * Description: converts BPM to Float
     * Parameters: BPM of the song in its string format
     * Output: BPM extract from the string in float
     */

    func convertBPMToFloat(_ bpmString: String) -> Float {
        // Really dirty way to parse the string return form BPMAnalyzer
        // Definitely a better way to do this
        let bpmSplitArray = bpmString.components(separatedBy: " ")
        let splitBPMSpaces = bpmSplitArray[2]
        let splitBPMComma = splitBPMSpaces.components(separatedBy: ",")
        let toBeConvertedFromString = splitBPMComma[0]
        let bpmFloat = Float(toBeConvertedFromString)
        
        return bpmFloat!
    }
    /**
     * Method name: setInitialMPH
     * Description: sets MPH to the saved value
     * Parameters: N/A
     */
    @objc
    func setInitialMPH(){
        if UserDefaults.standard.object(forKey: "Pace") != nil{
            MPH.text = UserDefaults.standard.object(forKey: "Pace") as? String
        }else{
            MPH.text = String(0)
        }
        chosenMPH = Int(MPH.text!)!
    }
    
    
    
    
    
    @IBAction func addSongButton(_ sender: Any) {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypeMP3)], in: .import)
         documentPicker.delegate = self
         if #available(iOS 11.0, *) {
            documentPicker.allowsMultipleSelection = true
         }
         self.present(documentPicker, animated: false) {
        
         }
    }
    
    
    
    
    
    /**
     * Method name:fixedTapped
     * Description: transforms the UI when the Fixed Button is tapped
     * Parameters: N/A
     */
    @IBAction func fixedTapped(_ sender: selectorButton) {
        fixedHideorNot(value: false)
        descriptionText.text = "Choose what pace you want to jog at"
        fixedAutoSwap(tapped: fixedButton, other: autoButton)
        titleLabel.text = "Manual Play"
    }
    /**
     * Method name: autoTapped
     * Description: transforms the UI when the Auto Button is tapped
     * Parameters: N/A
     */
    @IBAction func autoTapped(_ sender: selectorButton) {
        fixedHideorNot(value: true)
        descriptionText.text = "Let our algorithm match the pace"
        fixedAutoSwap(tapped: autoButton, other: fixedButton)
        titleLabel.text = "Smart Play"
        
    }
    /**
     * Method name:fixedHideorNot
     * Description: helper function to hide UI elements
     * Parameters: N/A
     */
    func fixedHideorNot(value: Bool){
        walkJogRunStack.isHidden = value
        mphStack.isHidden = value
        plusButton.isHidden = value
        minusButton.isHidden = value
        manualSmart = value
    }
    /**
     * Method name: fixedAutoSwap
     * Description: used to swap color of Fixed or Auto button when one is tapped
     * Parameters: a tapped button and the other button
     */
    func fixedAutoSwap(tapped: selectorButton, other: selectorButton ){
        if (tapped.isEnabled == true){
            tapped.isSelected()
            other.isUnselected()
        }else{
            tapped.isUnselected()
            other.isSelected()
        }
    }
    /**
     * Method name: walkTapped
     * Description: Listener for the walk button. Changes MPH to 4 and saves value.
     * Parameters: N/A
     */
    @IBAction func walkTapped(_ sender: Any) {
        MPH.text = "4"
        UserDefaults.standard.set(MPH.text, forKey:"Pace") // save value
        chosenMPH = Int(MPH.text!)!
    }
    /**
     * Method name: jogTapped
     * Description:  Listener for the jog button. Changes MPH to 6 and saves value.
     * Parameters: N/A
     */
    @IBAction func jogTapped(_ sender: Any) {
        MPH.text = "6"
        UserDefaults.standard.set(MPH.text, forKey:"Pace") // save value
        chosenMPH = Int(MPH.text!)!
    }
    /**
     * Method name: runTapped
     * Description:  Listener for the run button. Changes MPH to 48and saves value.
     * Parameters: N/A
     */
    @IBAction func runTapped(_ sender: Any) {
        MPH.text = "8"
        UserDefaults.standard.set(MPH.text, forKey:"Pace") // save value
        chosenMPH = Int(MPH.text!)!
    }
    
    /**
     * Method name: incrementMPH
     * Description: Increments the MPH, but MPH to 15
     * Parameters: N/A
     */
    @IBAction func incrementMPH(_ sender: Any) {
        let MPHInt: Int? = Int(MPH.text!)
        if MPHInt! < higherBoundMPH{
            MPH.text = String(MPHInt! + 1)
            UserDefaults.standard.set(MPH.text, forKey:"Pace") // save value
            chosenMPH = Int(MPH.text!)!
        }
    }
    /**
     * Method name: decrementMPH
     * Description: Decrements the MPH, but MPH to 0
     * Parameters: N/A
     */
    @IBAction func decrementMPH(_ sender: Any) {
        let MPHInt: Int? = Int(MPH.text!)
        if MPHInt! > lowerBoundMPH{
            MPH.text = String(MPHInt! - 1)
            UserDefaults.standard.set(MPH.text, forKey:"Pace") // save value
            chosenMPH = Int(MPH.text!)!
        }
    }
    
    /*
     * Method name: unwindToSelectionViewController
     * Description: used by the Finish button in the finish view controller to jump back to the selection view screen
     * Parameters: N/A
     */
    @IBAction func unwindToSelectionViewController(segue:UIStoryboardSegue) { }
    
    /*
    * Method name: saveButtonTapped
    * Description: Once tapped, this button dismisses the view and returns the previous screen. It also sends data to the previous screen.
    * Parameters: the UI element mapped to this function
    */
    @IBAction func saveButtonTapped(_ sender: Any) {
        if saveButton.title(for: .normal) == "Select Songs"{
            
            //let picker = MPMediaPickerController(mediaTypes:MPMediaType.anyAudio)
            //picker.allowsPickingMultipleItems = true
            //picker.showsCloudItems = true
            //picker.delegate = self
            saveButton.setSaveIcon()
            //self.present(picker, animated:false, completion:nil)
            
        }else if saveButton.title(for: .normal) == "Start Run!"{  //send data to Curtain View because Save has been tapped
            
            //code to show Map View
            let storyboard : UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let vc = storyboard.instantiateViewController(withIdentifier: "MapViewController") as! MapViewController

            vc.audioPlayer = audioPlayer
            vc.SongsArr = SongsArr

            vc.modalPresentationStyle = .currentContext
            present(vc, animated: true, completion:nil)
        }
    }
    /**
     * Method name: removeSuffix
     * Description: <#description#>
     * Parameters: <#parameters#>
     */
    func removeSuffix(songURL: String) -> String{
        let reversed = songURL.reversed()
        var output = ""
        var adding = false
        for letter in reversed{
            if adding{
                output += String(letter)
            }else if String(letter) == "."{
                adding = true
            }else{
                break
            }
        }
        return String(String(output).reversed())
    }
    
    
    deinit{
        //stop listening to notifications
        NotificationCenter.default.removeObserver(self, name: SelectionViewController.TimerNotification, object: nil)
    }
}


extension SelectionViewController: UIDocumentPickerDelegate{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let selectedFileURL = urls
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        let newSong = SongsDataModel(context: self.context)
        
        newSong.songsURL = urls[0].absoluteString
        
        let title =  removeSuffix(songURL: urls[0].absoluteString)
        let filePathSong = Bundle.main.path(forResource: title, ofType: "mp3", inDirectory: "Songs")
        let songUrl = URL(string: filePathSong!)
        let bpmGetter = BPMAnalyzer.core.getBpmFrom(songUrl!, completion: nil)
        newSong.songsBPM = String(convertBPMToFloat(bpmGetter))
        
        do{
            try context.save()
            
            self.songsData = try context.fetch(SongsDataModel.fetchRequest())
            for song in songsData!{
                print("songBPM ", song.songsBPM)
                let newSong = Song(title: song.songsURL!, BPM: Float(song.songsBPM!)!, played: false)
                SongsArr.append(newSong)
                
                print("title: ", SongsArr[0].title)

                try play(URL(string: SongsArr[0].title)!)
            }

        }catch{
            print(error)
        }
    }
}
