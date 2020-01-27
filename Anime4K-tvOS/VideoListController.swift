//
//  VideoListController.swift
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/25.
//  Copyright © 2019 xieyi. All rights reserved.
//

import Foundation
import UIKit

class VideoListController: UITableViewController {
    
    var videos: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let documentUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let files = try! FileManager.default.contentsOfDirectory(at: documentUrl, includingPropertiesForKeys: nil, options: [])
        videos = files.filter({s in s.lastPathComponent.lowercased().hasSuffix(".mp4")})
        videos.forEach({v in debugPrint(v)})
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if section == 1 {
            return videos.count
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = UITableViewHeaderFooterView()
            header.textLabel?.text = "Input URL"
            return header
        }
        if section == 1 {
            let header = UITableViewHeaderFooterView()
            header.textLabel?.text = "Content of Caches"
            return header
        }
        return nil
    }
    
    weak var textField: UITextField?
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        if indexPath.section == 0 {
            let textField = UITextField()
            textField.text = UserDefaults.standard.string(forKey: "stored_url")
            self.textField = textField
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(textField)
            cell.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-5-[textField]-5-|", options: .directionLeadingToTrailing, metrics: nil, views: ["textField": textField]))
            cell.contentView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-10-[textField]-10-|", options: .directionLeadingToTrailing, metrics: nil, views: ["textField": textField]))
            return cell
        }
        guard indexPath.section == 1 && indexPath.row < videos.count else {
            return cell
        }
        cell.textLabel?.text = videos[indexPath.row].lastPathComponent
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            textField?.becomeFirstResponder()
        }
        guard indexPath.section == 1 else {
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let player = storyboard.instantiateViewController(identifier: "player") as! PlayerController
        player.videoUrl = videos[indexPath.row]
        navigationController?.pushViewController(player, animated: true)
    }
    
}

extension VideoListController: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let textUrl = textField.text, let url = URL(string: textUrl) else {
            return
        }
        UserDefaults.standard.set(textUrl, forKey: "stored_url")
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let player = storyboard.instantiateViewController(identifier: "player") as! PlayerController
        player.videoUrl = url
        navigationController?.pushViewController(player, animated: true)
    }
    
}
