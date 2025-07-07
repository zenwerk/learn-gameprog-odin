package chap01_simple_pong

// エントリーポイント
main :: proc() {
    // ゲーム構造体のインスタンスを作成
    game: Game
    
    // ゲームを初期化
    // 初期化に失敗した場合は終了
    if game_initialize(&game) {
        // ゲームループを実行
        // この関数はゲームが終了するまでブロックされる
        game_run_loop(&game)
    }
    
    // ゲームのクリーンアップ処理
    // ウィンドウ、レンダラー、SDLの終了処理を行う
    game_shutdown(&game)
}