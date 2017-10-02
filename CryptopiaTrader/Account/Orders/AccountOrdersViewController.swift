//
//  AccountOrdersViewController.swift
//  CryptopiaTrader
//
//  Created by Florin Uscatu on 9/30/17.
//  Copyright © 2017 Florin Uscatu. All rights reserved.
//

import UIKit
import CryptoSwift
import JSSAlertView

struct Orders: Decodable {
    var Data: [Order]
    var Error: String?
    var Success: Int
}

struct Order: Decodable {
    var Amount: Double
    var Market: String
    var OrderId: Int
    var Rate: Double
    var Remaining: Double
    var TimeStamp: String
    var Total: Double
    var `Type`: String
}

class AccountOrdersViewController: UITableViewController {

    @IBOutlet var headerView: UIView!
    
    var ordersArray: [Order] = []
    
    var ordersRefreshControl = UIRefreshControl()

    //getting the key
    var key: String {
        if UserDefaults.standard.value(forKey: "key") != nil {
            return UserDefaults.standard.value(forKey: "key") as! String
        } else {
            print("there is no key")
            return ""
        }
    }
    
    //getting the secret
    var secret: String {
        if UserDefaults.standard.value(forKey: "secret") != nil {
            return UserDefaults.standard.value(forKey: "secret") as! String
        } else {
            print("there is no secret")
            return ""
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Setup for refresh control
        ordersRefreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        ordersRefreshControl.addTarget(self, action: #selector(AccountOrdersViewController.refresh), for: .allEvents)
        tableView.refreshControl = ordersRefreshControl
    }
    
    //Refresh the tableView when selector is triggered
    @objc func refresh() {
        requestDataLocally()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        requestDataLocally()
    }
    
    func requestDataLocally() {
        ApiCalls().requestData(publicType: false, method: "GetOpenOrders", parameters: [:], key: key, secret: secret) { (data) in
            do {
                let tempArray = try JSONDecoder().decode(Orders.self, from: data)
                self.ordersArray = tempArray.Data
                DispatchQueue.main.async {
                    self.ordersRefreshControl.endRefreshing()
                    self.tableView.reloadData()
                }
            } catch let err {
                print(err)
                self.ordersRefreshControl.endRefreshing()
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return ordersArray.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ordersCell", for: indexPath) as! OrdersCell
        
        let dateString = ordersArray[indexPath.row].TimeStamp.split(separator: "T")
        let datePart = dateString[0]
        let timePart = dateString[1].split(separator: ".")
        let timeWithoutSecondsPart = timePart[0]
        let finalDateString:String = datePart + " " + timeWithoutSecondsPart
        
        cell.amount.text = "Amount: " + String(ordersArray[indexPath.row].Amount)
        cell.market.text = ordersArray[indexPath.row].Market
        cell.date.text = finalDateString
        cell.rate.text = "Rate: " + String(format: "%.8f", ordersArray[indexPath.row].Rate)
        cell.total.text = "Total: " + String(format: "%.8f", ordersArray[indexPath.row].Total)
        cell.type.text = ordersArray[indexPath.row].Type
        cell.remaining.text = "Remaining: " + String(format: "%.8f", ordersArray[indexPath.row].Remaining)
        
        switch ordersArray[indexPath.row].Type {
        case "Buy":
            cell.type.textColor = UIColor.green
        case "Sell":
            cell.type.textColor = UIColor.red
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    //Outlets for the canceling orders button
    @IBOutlet weak var cancelOrderBttn: UIButton!
    @IBAction func cancelOrder(_ sender: UIButton) {
        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
            sender.setTitle("Cancel Orders", for: .normal)
        } else {
            tableView.setEditing(true, animated: true)
            sender.setTitle("Done", for: .normal)
        }
        print("fun")
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            //Getting the order id from the array
            let orderId = ordersArray[indexPath.row].OrderId
            //Api call for canceling the order
            ApiCalls().requestData(publicType: false, method: "CancelTrade", parameters: ["Type":"Trade", "OrderId":orderId], key: key, secret: secret, completionHandler: { (data) in
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? NSDictionary
                    guard let success:Int = jsonData?.value(forKey: "Success") as? Int else {return}
                    guard let error = jsonData?.value(forKey: "Error") else {return}
                    
                    if success == 1 {
                        //In case everything runs smooth
                        DispatchQueue.main.async {
                            tableView.setEditing(false, animated: true)
                            self.requestDataLocally()
                            self.cancelOrderBttn.setTitle("Cancel Orders", for: .normal)
                            JSSAlertView().success(
                                self,
                                title: "Success",
                                text: "Your order has been canceled"
                            )
                        }
                    } else {
                        //In case there is an error
                        DispatchQueue.main.async {
                            tableView.setEditing(false, animated: true)
                            self.requestDataLocally()
                            self.cancelOrderBttn.setTitle("Cancel Orders", for: .normal)
                            JSSAlertView().danger(
                                self,
                                title: "Failure",
                                text: String(describing: error)
                            )
                        }
                    }
                } catch let err {
                    print(err)
                }
            })
        }
    }
}