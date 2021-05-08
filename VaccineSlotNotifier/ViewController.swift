//
//  ViewController.swift
//  VaccineSlotNotifier
//
//  Created by Kanakatti Shrikant on 06/05/21.
//

import UIKit
import Alamofire
import SwiftyJSON
import ObjectMapper
import UserNotifications
import Toast_Swift

class ViewController: UIViewController, UNUserNotificationCenterDelegate {

    //MARK:- Variable declaration

    @IBOutlet weak var tfPinCode: UITextField!
    @IBOutlet weak var btnFindSlotNotify: UIButton!
    @IBOutlet weak var tfDate: UITextField!
    var datePicker :UIDatePicker!
    var slotTimer: Timer?

    //MARK:- View life cycle methods

    override func viewDidLoad() {
        super.viewDidLoad()
        self.requestNotificationPermission()
        self.tfDate.setInputViewDatePicker(target: self, selector: #selector(tapDone))
        self.setDateToTextField(date: Date())
    }
    //MARK:- Button events

    @IBAction func btnNotifyClicked(_ sender: Any) {
        if !tfPinCode.text!.isEmpty && tfPinCode.text!.count == 6 {
            slotTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(getDetails), userInfo: nil, repeats: true)
            self.getDetails()
        }
        else {
            self.tfPinCode.resignFirstResponder()
            self.view.makeToast("Invalid pincode", duration: 2.0, position: .center)
        }
    }
    
    //MARK:- Helpers

    @objc private func getDetails() {
        if slotTimer != nil {
            let headers: HTTPHeaders = [
                "User-Agent" : "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.2171.95 Safari/537.36"
            ]
            DispatchQueue.main.async {
                
                AF.request("https://cdn-api.co-vin.in/api/v2/appointment/sessions/public/findByPin?pincode=\(self.tfPinCode.text!)&date=\(self.tfPinCode.text!)", method: .get, parameters: nil, headers:headers)
                   .responseData { (response) in
                       switch response.result {
                       case .success(let value):
                        if let responseData = String(data: value, encoding: .utf8) {
                            self.tfPinCode.resignFirstResponder()
                            let baseSesssionResponse = Mapper<BaseSessionResponse>().map(JSONString: responseData)
                            if let sessions = baseSesssionResponse?.sessions, sessions.count > 0 {
                                if sessions.first!.available_capacity! > 0 && sessions.first!.min_age_limit! > 0 {
                                    self.slotTimer = nil
                                    self.slotTimer?.invalidate()
                                    self.triggerLocalNotification(availableCount: sessions.first!.available_capacity!, ageLimit: sessions.first!.min_age_limit!)
                                }
                                else {
                                    self.view.makeToast("No slots are available at this pincode", duration: 2.0, position: .center)
                                }
                            }
                            else {
                                self.displayNoSlotAvailableText()
                            }
                        } else {
                            self.tfPinCode.resignFirstResponder()
                            self.displayNoSlotAvailableText()
                        }
                        case .failure(_):
                            self.tfPinCode.resignFirstResponder()
                            self.displayNoSlotAvailableText()
                       }
               }
           }
        }
    }

    private func displayNoSlotAvailableText() {
        self.view.makeToast("No slots are available at this pincode", duration: 2.0, position: .center)
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge], completionHandler: {didAllow, error in
            UNUserNotificationCenter.current().delegate = self
        })
    }
    
    private func triggerLocalNotification(availableCount:Int, ageLimit: Int) {
        let displayText = "Hello, there is slot available at your pincode. The age group is \(ageLimit) and only \(availableCount) are available."
        self.view.makeToast(displayText, duration: 8.0, position: .center)
        let content = UNMutableNotificationContent()
        content.title = "COWIN"
        content.subtitle = "Slot Available Status"
        content.body = displayText
        content.badge = 1
        content.launchImageName = "COWIN"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "CowinSlotNotification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent
        notification: UNNotification, withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void) {
        return completionHandler(UNNotificationPresentationOptions.banner)
    }
    
    @objc func tapDone() {
        if let datePicker = self.tfDate.inputView as? UIDatePicker {
            self.setDateToTextField(date: datePicker.date)
        }
        self.tfDate.resignFirstResponder()
    }
    
    private func setDateToTextField(date: Date) {
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "dd-MM-yyyy"
        self.tfDate.text = dateformatter.string(from: date)
    }
   
}

extension Date {
    func string(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

extension UITextField {
    
    func setInputViewDatePicker(target: Any, selector: Selector) {
        let screenWidth = UIScreen.main.bounds.width
        let datePicker = UIDatePicker(frame: CGRect(x: 0, y: 0, width: screenWidth, height: 216))
        datePicker.datePickerMode = .date
        let today = Date()
        let tomm = Calendar.current.date(byAdding: .day, value: 6, to: today)!
        datePicker.minimumDate = today
        datePicker.maximumDate = tomm
        
        if #available(iOS 14, *) {
          datePicker.preferredDatePickerStyle = .wheels
          datePicker.sizeToFit()
        }
        self.inputView = datePicker
        
        let toolBar = UIToolbar(frame: CGRect(x: 0.0, y: 0.0, width: screenWidth, height: 44.0))
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain, target: nil, action: #selector(tapCancel))
        let barButton = UIBarButtonItem(title: "Done", style: .plain, target: target, action: selector)
        toolBar.setItems([cancel, flexible, barButton], animated: false)
        self.inputAccessoryView = toolBar
    }
    
    @objc func tapCancel() {
        self.resignFirstResponder()
    }
    

}
//MARK:- Response Handling

struct BaseSessionResponse : Mappable {
    var sessions : [Sessions]?
    init?(map: Map) {

    }
    mutating func mapping(map: Map) {
        sessions <- map["sessions"]
    }
}

struct Sessions : Mappable {
    var center_id : Int?
    var name : String?
    var address : String?
    var state_name : String?
    var district_name : String?
    var block_name : String?
    var pincode : Int?
    var from : String?
    var to : String?
    var lat : Int?
    var long : Int?
    var fee_type : String?
    var session_id : String?
    var date : String?
    var available_capacity : Int?
    var fee : String?
    var min_age_limit : Int?
    var vaccine : String?
    var slots : [String]?

    init?(map: Map) {

    }

    mutating func mapping(map: Map) {

        center_id <- map["center_id"]
        name <- map["name"]
        address <- map["address"]
        state_name <- map["state_name"]
        district_name <- map["district_name"]
        block_name <- map["block_name"]
        pincode <- map["pincode"]
        from <- map["from"]
        to <- map["to"]
        lat <- map["lat"]
        long <- map["long"]
        fee_type <- map["fee_type"]
        session_id <- map["session_id"]
        date <- map["date"]
        available_capacity <- map["available_capacity"]
        fee <- map["fee"]
        min_age_limit <- map["min_age_limit"]
        vaccine <- map["vaccine"]
        slots <- map["slots"]
    }

}


