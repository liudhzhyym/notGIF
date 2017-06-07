//
//  SideBarViewController.swift
//  notGIF
//
//  Created by ooatuoo on 2017/6/1.
//  Copyright © 2017年 xyz. All rights reserved.
//

import UIKit
import RealmSwift

// 添加 Tag 时插入的位置
private let newTagCellInsertIP = IndexPath(item: 1, section: 0)
private let rowHeight: CGFloat = 44

class SideBarViewController: UIViewController {
    
    fileprivate var isAddingTag: Bool = false {
        didSet {    // 编辑时禁止返回
            guard let drawer = parent as? DrawerViewController else { return }
            drawer.mainContainer.isUserInteractionEnabled = !isAddingTag
        }
    }
    
    fileprivate var selectedTag: Tag!
    
    fileprivate var tagList: [Tag] = []
    fileprivate var notifiToken: NotificationToken?
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.tableFooterView = UIView()
            tableView.rowHeight = rowHeight
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let realm = try? Realm() else { return }
        
        let tagResult = realm.objects(Tag.self).sorted(byKeyPath: "createDate", ascending: false)
        tagList.append(contentsOf: tagResult)
        
        notifiToken = tagResult.addNotificationBlock { [weak self] changes in
            guard let tableView = self?.tableView else { return }
            
            switch changes {
            case .initial:
                tableView.reloadData()
                
            case .update(_, let deletions, let insertions, let modifications):
                tableView.beginUpdates()
//                tableView.insertRows(at: insertions.map({ IndexPath(row: $0, section: 0) }), with: .fade)
//                tableView.deleteRows(at: deletions.map({ IndexPath(row: $0, section: 0)}), with: .fade)
                tableView.reloadRows(at: modifications.map({ IndexPath(row: $0, section: 0) }), with: .fade)
                tableView.endUpdates()
                
            case .error(let err):
                print(err.localizedDescription)
            }
        }
    
    }
    
    deinit {
        notifiToken?.stop()
        notifiToken = nil
    }
    
    @IBAction func addTagButtonClicked(_ sender: UIButton) {
        guard !isAddingTag, tagList.count > 0 else { return }
        
        UIView.animate(withDuration: 0.2, animations: { 
            self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
            self.tableView.setEditing(false, animated: false)

        }) { _ in
            
            self.isAddingTag = true
            self.tagList.insert(Tag(name: ""), at: newTagCellInsertIP.item)
            self.tableView.insertRows(at: [newTagCellInsertIP], with: .top)
            self.beginEditTag(at: newTagCellInsertIP)
        }
    }
}

extension SideBarViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tagList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TagListCell = tableView.dequeueReusableCell()
        cell.configure(with: tagList[indexPath.item])

        cell.editDoneHandler = { [unowned self] text in
            guard let realm = try? Realm(),
                let editIP = tableView.indexPath(for: cell) else { return }
            
            try? realm.write {
                realm.add(self.tagList[editIP.item].update(with: text), update: true)
            }
        }
        
        cell.editCancelHandler = { [unowned self] in
            self.tagList.remove(at: newTagCellInsertIP.item)
            tableView.deleteRows(at: [newTagCellInsertIP], with: .bottom)
        }
        
        cell.endEditHandler = { [unowned self] in
            self.isAddingTag = false
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        guard !isAddingTag, let drawer = parent as? DrawerViewController else { return }
        
        let tag = tagList[indexPath.item]
        selectedTag = tag

        NotificationCenter.default.post(name: .didSelectTag, object: tag)
        drawer.dismissSideBar()
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let actionSize = CGSize(width: 40, height: rowHeight)
        let editRowAction = UITableViewRowAction(size: actionSize, image: #imageLiteral(resourceName: "icon_tag_edit"), bgColor: .editYellow) {
            [unowned self] (_, rowActionIP) in
            self.beginEditTag(at: rowActionIP)
        }
        
        let deleteRowAction = UITableViewRowAction(size: actionSize, image: #imageLiteral(resourceName: "icon_tag_delete"), bgColor: .deleteRed) {
            [unowned self] (_, rowActionIP) in
            self.deleteTag(at: rowActionIP)
        }
        
        return [editRowAction, deleteRowAction]
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !isAddingTag && tagList[indexPath.item].id != Config.defaultTagID
    }
}

extension SideBarViewController {
    
    fileprivate func beginEditTag(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? TagListCell else { return }
        tableView.setEditing(false, animated: true)
        cell.beginEdit()
    }
    
    fileprivate func deleteTag(at indexPath: IndexPath) {
        guard let realm = try? Realm() else { return }
        try? realm.write {
            realm.delete(tagList[indexPath.item])
        }
        
        tagList.remove(at: indexPath.item)
        tableView.deleteRows(at: [indexPath], with: .left)
    }
}