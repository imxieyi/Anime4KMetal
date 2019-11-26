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
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? videos.count : 0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 {
            let header = UITableViewHeaderFooterView()
            header.textLabel?.text = "Content of Caches"
            return header
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        guard indexPath.section == 0 && indexPath.row < videos.count else {
            return cell
        }
        cell.textLabel?.text = videos[indexPath.row].lastPathComponent
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let player = storyboard.instantiateViewController(identifier: "player") as! PlayerController
        player.videoUrl = videos[indexPath.row]
        navigationController?.pushViewController(player, animated: true)
    }
    
}
