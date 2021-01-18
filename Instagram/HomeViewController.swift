//
//  HomeViewController.swift
//  Instagram
//
//  Created by HY on 2020/12/24.
//  Copyright © 2020 HY. All rights reserved.
//

import UIKit
import Firebase

class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    // 投稿データを格納する配列
    var postArray: [PostData] = []
    
    // Firestoreのリスナー
    var listener: ListenerRegistration!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        tableView.delegate = self
        tableView.dataSource = self

        // カスタムセルを登録する
        let nib = UINib(nibName: "PostTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "Cell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("DEBUG_PRINT: viewWillAppear")

        if Auth.auth().currentUser != nil {
            // ログイン済み
            if listener == nil {
                // listener未登録なら、登録してスナップショットを受信する
                let postsRef = Firestore.firestore().collection(Const.PostPath).order(by: "date", descending: true)
                listener = postsRef.addSnapshotListener() { (querySnapshot, error) in
                    if let error = error {
                        print("DEBUG_PRINT: snapshotの取得が失敗しました。 \(error)")
                        return
                    }
                    // 取得したdocumentをもとにPostDataを作成し、postArrayの配列にする。
                    self.postArray = querySnapshot!.documents.map { document in
                        print("DEBUG_PRINT: document取得 \(document.documentID)")
                        let postData = PostData(document: document)
                        return postData
                    }
                    // TableViewの表示を更新する
                    self.tableView.reloadData()
                }
            }
        } else {
            // ログイン未(またはログアウト済み)
            if listener != nil {
                // listener登録済みなら削除してpostArrayをクリアする
                listener.remove()
                listener = nil
                postArray = []
                tableView.reloadData()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // セルを取得してデータを設定する
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! PostTableViewCell
        cell.setPostData(postArray[indexPath.row])

        // セル内のいいねボタンのアクションをソースコードで設定する
        cell.likeButton.addTarget(self, action:#selector(handleButton(_:forEvent:)), for: .touchUpInside)

        // セル内のコメントボタンのアクションをソースコードで設定する
        cell.commentButton.addTarget(self, action:#selector(commentHandleButton(_:forEvent:)), for: .touchUpInside)

        return cell
    }

    // セル内のコメントボタンがタップされた時に呼ばれるメソッド
    @objc func commentHandleButton(_ sender: UIButton, forEvent event: UIEvent) {

        print("DEBUG_PRINT: コメントボタンがタップされました。")

        // コメント入力フィールド
        var alertTextField: UITextField?
        
        // タップされたセルのインデックスを求める
        let touch = event.allTouches?.first
        let point = touch!.location(in: self.tableView)
        let indexPath = tableView.indexPathForRow(at: point)

        // 配列からタップされたインデックスのデータを取り出す
        let postData = postArray[indexPath!.row]

        // ポップアップ生成
        let alert = UIAlertController(title: "コメント入力",message: "",preferredStyle: UIAlertController.Style.alert)

        // ポップアップにテキストフィールド追加
        alert.addTextField(configurationHandler: {(textField: UITextField!) in alertTextField = textField})

        // ポップアップにキャンセルボタン追加
        alert.addAction(UIAlertAction(title: "Cancel",style: UIAlertAction.Style.cancel,handler: nil))

        // ポップアップにOKボタン追加
        alert.addAction(UIAlertAction(title: "OK",style: UIAlertAction.Style.default) { _ in
            if let text = alertTextField?.text {
                        
                // OKボタン押されて入力フィールドが空じゃないとき
                if text != "" {

                    // 更新するデータをidで取得する
                    let postRef = Firestore.firestore().collection(Const.PostPath).document(postData.id)
                        
                    // コメント投稿者名を取得
                    let userName = Auth.auth().currentUser?.displayName

                    // コメント文字列作成（ユーザー名＋コメント）
                    let commentData = userName! + " : " + text
                    
                    // コメントデータをDB更新用にする
                    let updateValue = FieldValue.arrayUnion([commentData])

                    // データ更新
                    postRef.updateData(["comment" : updateValue])
                }
            }
        })
        // コメント入力ポップアップ表示
        self.present(alert, animated: true, completion: nil)
    }
     
    // セル内のボタンがタップされた時に呼ばれるメソッド
    @objc func handleButton(_ sender: UIButton, forEvent event: UIEvent) {
        print("DEBUG_PRINT: likeボタンがタップされました。")

        // タップされたセルのインデックスを求める
        let touch = event.allTouches?.first
        let point = touch!.location(in: self.tableView)
        let indexPath = tableView.indexPathForRow(at: point)

        // 配列からタップされたインデックスのデータを取り出す
        let postData = postArray[indexPath!.row]

        // likesを更新する
        if let myid = Auth.auth().currentUser?.uid {
            // 更新データを作成する
            var updateValue: FieldValue
            if postData.isLiked {
                // すでにいいねをしている場合は、いいね解除のためmyidを取り除く更新データを作成
                updateValue = FieldValue.arrayRemove([myid])
            } else {
                // 今回新たにいいねを押した場合は、myidを追加する更新データを作成
                updateValue = FieldValue.arrayUnion([myid])
            }
            // likesに更新データを書き込む
            let postRef = Firestore.firestore().collection(Const.PostPath).document(postData.id)
            postRef.updateData(["likes": updateValue])
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
