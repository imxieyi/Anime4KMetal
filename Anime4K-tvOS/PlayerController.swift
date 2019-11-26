//
//  PlayerController.swift
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/26.
//  Copyright © 2019 xieyi. All rights reserved.
//

import Foundation
import UIKit
import AVKit

class PlayerController: AVPlayerViewController {
    
    var videoUrl: URL?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let videoUrl = videoUrl else {
            return
        }
        appliesPreferredDisplayCriteriaAutomatically = true
        player = AVPlayer(url: videoUrl)
        player?.preventsDisplaySleepDuringVideoPlayback = true
        player?.play()
    }
    
}
