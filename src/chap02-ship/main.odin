package chap02_ship

// プログラムのエントリーポイント
main :: proc() {
    // ゲームインスタンスを作成
    game: Game
    
    // ゲームシステムを初期化
    // SDL、ウィンドウ、レンダラー、テクスチャローダーなどをセットアップ
    success := game_initialize(&game)
    
    if success {
        // ゲームループを開始
        // この関数はゲームが終了するまでブロックされる
        // 1. 入力処理 (ProcessInput)
        // 2. ゲーム状態更新 (UpdateGame) 
        // 3. 画面描画 (GenerateOutput)
        // の順で毎フレーム実行される
        game_run_loop(&game)
    }
    
    // ゲーム終了時のクリーンアップ処理
    // メモリ解放、SDL終了、ファイルクローズなど
    game_shutdown(&game)
}