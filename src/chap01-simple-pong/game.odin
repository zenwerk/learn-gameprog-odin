package chap01_simple_pong

import sdl "vendor:sdl3"

// 定数定義
THICKNESS :: 15
PADDLE_HEIGHT :: 100.0

// Vector2はOdinの配列型として定義
Vec2 :: [2]f32

// Gameクラスの代わりに、データを保持する構造体を定義
Game :: struct {
    // SDLウィンドウとレンダラー
    window:     ^sdl.Window,
    renderer:   ^sdl.Renderer,
    
    // ゲームループ用の時間管理
    ticks_count: u64,
    is_running:  bool,
    
    // Pong固有のゲーム状態
    paddle_dir:  int,      // パドルの移動方向 (-1: 上, 0: 停止, 1: 下)
    paddle_pos:  Vec2,     // パドルの位置
    ball_pos:    Vec2,     // ボールの位置
    ball_vel:    Vec2,     // ボールの速度ベクトル
}

// ゲームの初期化
game_initialize :: proc(game: ^Game) -> bool {
    // SDLビデオサブシステムの初期化
    if !sdl.Init({.VIDEO}) {
        sdl.LogError(i32(sdl.LogCategory.ERROR), "Unable to initialize SDL: %s", sdl.GetError())
        return false
    }
    
    // ウィンドウの作成
    // 位置(100, 100)、サイズ1024x768のウィンドウを作成
    game.window = sdl.CreateWindow(
        "Game Programming in Odin (Chapter 1)", 
        1024, 768,
        {},
    )
    
    if game.window == nil {
        sdl.LogError(i32(sdl.LogCategory.ERROR), "Failed to create window: %s", sdl.GetError())
        return false
    }
    
    // レンダラーの作成（ハードウェアアクセラレーション + VSync有効）
    game.renderer = sdl.CreateRenderer(game.window, nil)
    
    if game.renderer == nil {
        sdl.LogError(i32(sdl.LogCategory.ERROR), "Failed to create renderer: %s", sdl.GetError())
        return false
    }
    
    // VSyncを有効にする
    sdl.SetRenderVSync(game.renderer, sdl.RENDERER_VSYNC_ADAPTIVE)
    
    // ゲームオブジェクトの初期位置設定
    game.paddle_pos = {10.0, 768.0 / 2.0}         // パドルを画面左端、縦中央に配置
    game.ball_pos = {1024.0 / 2.0, 768.0 / 2.0}  // ボールを画面中央に配置
    game.ball_vel = {-200.0, 235.0}              // ボールの初期速度（左斜め下方向）
    game.is_running = true
    
    return true
}

// ゲームループの実行
game_run_loop :: proc(game: ^Game) {
    for game.is_running {
        game_process_input(game)
        game_update(game)
        game_generate_output(game)
    }
}

// 入力処理
game_process_input :: proc(game: ^Game) {
    event: sdl.Event
    
    // イベントキューからイベントを取得
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            // ウィンドウの×ボタンが押された
            game.is_running = false
        }
    }
    
    // キーボードの状態を取得
    state := sdl.GetKeyboardState(nil)
    
    // ESCキーでゲーム終了
    if state[sdl.Scancode.ESCAPE] {
        game.is_running = false
    }
    
    // W/Sキーでパドルを上下に移動
    game.paddle_dir = 0
    if state[sdl.Scancode.W] {
        game.paddle_dir -= 1  // 上方向
    }
    if state[sdl.Scancode.S] {
        game.paddle_dir += 1  // 下方向
    }
}

// ゲームロジックの更新
game_update :: proc(game: ^Game) {
    // 前フレームから16ms（約60FPS）経過するまで待機
    // SDL3では単純な比較を使用
    for sdl.GetTicks() < game.ticks_count + 16 {
        // 待機
    }
    
    // デルタタイム（前フレームからの経過時間）を計算
    delta_time := f32(sdl.GetTicks() - game.ticks_count) / 1000.0
    
    // デルタタイムの上限を設定（処理落ち対策）
    if delta_time > 0.05 {
        delta_time = 0.05
    }
    
    // 次フレーム用に現在の時間を記録
    game.ticks_count = sdl.GetTicks()
    
    // パドルの位置更新
    if game.paddle_dir != 0 {
        // パドルを300ピクセル/秒の速度で移動
        game.paddle_pos.y += f32(game.paddle_dir) * 300.0 * delta_time
        
        // パドルが画面外に出ないように制限
        if game.paddle_pos.y < (PADDLE_HEIGHT/2.0 + THICKNESS) {
            game.paddle_pos.y = PADDLE_HEIGHT/2.0 + THICKNESS
        } else if game.paddle_pos.y > (768.0 - PADDLE_HEIGHT/2.0 - THICKNESS) {
            game.paddle_pos.y = 768.0 - PADDLE_HEIGHT/2.0 - THICKNESS
        }
    }
    
    // ボールの位置を速度に基づいて更新
    game.ball_pos += game.ball_vel * delta_time
    
    // パドルとの衝突判定
    diff := game.paddle_pos.y - game.ball_pos.y
    // 絶対値を取得
    diff = diff > 0.0 ? diff : -diff
    
    if diff <= PADDLE_HEIGHT / 2.0 &&                    // Y方向の距離が十分近い
       game.ball_pos.x <= 25.0 && game.ball_pos.x >= 20.0 &&  // X方向の位置が適切
       game.ball_vel.x < 0.0 {                           // ボールが左方向に移動中
        // ボールを反射させる
        game.ball_vel.x *= -1.0
    } else if game.ball_pos.x <= 0.0 {
        // ボールが画面左端を超えた（ゲームオーバー）
        game.is_running = false
    } else if game.ball_pos.x >= (1024.0 - THICKNESS) && game.ball_vel.x > 0.0 {
        // 右壁との衝突
        game.ball_vel.x *= -1.0
    }
    
    // 上壁との衝突判定
    if game.ball_pos.y <= THICKNESS && game.ball_vel.y < 0.0 {
        game.ball_vel.y *= -1.0
    } else if game.ball_pos.y >= (768.0 - THICKNESS) && game.ball_vel.y > 0.0 {
        // 下壁との衝突
        game.ball_vel.y *= -1.0
    }
}

// 画面描画
game_generate_output :: proc(game: ^Game) {
    // 背景色を青色に設定
    sdl.SetRenderDrawColor(game.renderer, 0, 0, 255, 255)
    // バックバッファをクリア
    sdl.RenderClear(game.renderer)
    
    // 描画色を白色に設定（壁、パドル、ボール用）
    sdl.SetRenderDrawColor(game.renderer, 255, 255, 255, 255)
    
    // 上壁を描画
    wall := sdl.FRect{0, 0, 1024, THICKNESS}
    sdl.RenderFillRect(game.renderer, &wall)
    
    // 下壁を描画
    wall.y = 768 - THICKNESS
    sdl.RenderFillRect(game.renderer, &wall)
    
    // 右壁を描画
    wall.x = 1024 - THICKNESS
    wall.y = 0
    wall.w = THICKNESS
    wall.h = 768
    sdl.RenderFillRect(game.renderer, &wall)
    
    // パドルを描画（中心座標から矩形を計算）
    paddle := sdl.FRect{
        game.paddle_pos.x,
        game.paddle_pos.y - PADDLE_HEIGHT/2,
        THICKNESS,
        PADDLE_HEIGHT,
    }
    sdl.RenderFillRect(game.renderer, &paddle)
    
    // ボールを描画（正方形として描画）
    ball := sdl.FRect{
        game.ball_pos.x - THICKNESS/2,
        game.ball_pos.y - THICKNESS/2,
        THICKNESS,
        THICKNESS,
    }
    sdl.RenderFillRect(game.renderer, &ball)
    
    // フロントバッファとバックバッファを入れ替えて画面に表示
    sdl.RenderPresent(game.renderer)
}

// ゲームの終了処理
game_shutdown :: proc(game: ^Game) {
    if game.renderer != nil {
        sdl.DestroyRenderer(game.renderer)
    }
    if game.window != nil {
        sdl.DestroyWindow(game.window)
    }
    sdl.Quit()
}