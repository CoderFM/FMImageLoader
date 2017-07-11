//
//  ViewController.swift
//  FMImageLoader
//
//  Created by 周发明 on 17/6/24.
//  Copyright © 2017年 周发明. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         http://wx4.sinaimg.cn/mw690/5eef6257gy1fhfqu4cqaig20b407lb29.gif
         http://pics.sc.chinaz.com/files/pic/pic9/201410/apic7065.jpg
         */
        
        self.imageView.fm_loadImage(url: "http://wx4.sinaimg.cn/mw690/5eef6257gy1fhfqu4cqaig20b407lb29.gif")
        
    }
}

