package chap03_asteroid

import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import "core:strings"
import "core:mem"

// ゲーム全体の状態を管理するメイン構造体
// すべてのゲームオブジェクト、システム、リソースを統括
Game :: struct {
    // SDL関連（グラフィクス・入力システム）
    window:   ^sdl.Window,    // ゲームウィンドウ
    renderer: ^sdl.Renderer,  // 描画用レンダラー
    
    // ゲームループ関連
    ticks_count:    u32,   // ゲーム開始からの経過時間（ミリ秒）
    is_running:     bool,  // ゲームが実行中かどうか
    updating_actors: bool, // アクター更新中フラグ（更新中の削除を防ぐ）
    
    // ゲームオブジェクト管理
    // データ指向設計：すべてのオブジェクトを配列で管理
    actors:         [dynamic]^Actor,           // 全アクター（船、小惑星、レーザーなど）
    pending_actors: [dynamic]^Actor,           // 追加待ちアクター
    sprites:        [dynamic]^Sprite_Component, // 描画対象スプライト群
    
    // リソース管理
    // テクスチャをファイル名をキーとしてキャッシュ
    textures: map[string]^sdl.Texture,
    
    // ゲーム固有オブジェクト
    ship: ^Actor,  // プレイヤーの宇宙船への参照
}

// ゲームの初期化
// SDL、ウィンドウ、レンダラーのセットアップとリソース読み込み
game_initialize :: proc(game: ^Game) -> bool {
    // macOSでのMachポートエラーを避けるため、VIDEOのみで初期化
    if sdl.Init({.VIDEO}) != 0 {
        sdl.Log("Unable to initialize SDL: %s", sdl.GetError())
        return false
    }
    
    // ゲームウィンドウの作成
    // アステロイドゲーム用の適切なサイズを設定
    game.window = sdl.CreateWindow(
        "Game Programming in Odin (Chapter 3: Asteroids)",
        100, 100,  // ウィンドウ位置
        1024, 768, // ウィンドウサイズ
        {},        // ウィンドウフラグ
    )
    
    if game.window == nil {
        sdl.Log("Failed to create window: %s", sdl.GetError())
        return false
    }
    
    // ハードウェアアクセラレーション付きレンダラーの作成
    // VSync（垂直同期）を有効にして滑らかな描画を実現
    game.renderer = sdl.CreateRenderer(game.window, -1, {.ACCELERATED, .PRESENTVSYNC})
    
    if game.renderer == nil {
        sdl.Log("Failed to create renderer: %s", sdl.GetError())
        return false
    }
    
    // SDL_imageの初期化（PNG画像読み込み用）
    if img.Init({.PNG}) == {} {
        sdl.Log("Unable to initialize SDL_image: %s", sdl.GetError())
        return false
    }
    
    // ゲーム状態の初期化
    game.actors = make([dynamic]^Actor)
    game.pending_actors = make([dynamic]^Actor)
    game.sprites = make([dynamic]^Sprite_Component)
    game.textures = make(map[string]^sdl.Texture)
    game.is_running = true
    game.updating_actors = false
    
    // ゲームデータの読み込み（アクター、テクスチャなど）
    game_load_data(game)
    
    // タイマーの初期化
    game.ticks_count = sdl.GetTicks()
    
    return true
}

// メインゲームループ
// ゲームが終了するまで入力処理→更新→描画を繰り返す
game_run_loop :: proc(game: ^Game) {
    for game.is_running {
        game_process_input(game)      // 1. 入力処理
        game_update_game(game)        // 2. ゲーム状態更新
        game_generate_output(game)    // 3. 画面描画
    }
}

// 入力処理
// キーボード・マウス入力とウィンドウイベントを処理
game_process_input :: proc(game: ^Game) {
    event: sdl.Event
    
    // イベントキューを処理
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            // ウィンドウの×ボタンが押された
            game.is_running = false
        }
    }
    
    // キーボード状態を取得
    state := sdl.GetKeyboardState(nil)
    
    // ESCキーでゲーム終了
    if state[sdl.SCANCODE_ESCAPE] != 0 {
        game.is_running = false
    }
    
    // 宇宙船固有の入力処理（レーザー発射など）
    if game.ship != nil {
        ship_process_input(game.ship, state)
    }
}

// ゲーム状態の更新
// フレームレート制御、アクター更新、衝突判定、削除処理
game_update_game :: proc(game: ^Game) {
    // フレームレート制御（60FPS = 16.67ms per frame）
    // 前フレームから十分な時間が経過するまで待機
    for !sdl.TICKS_PASSED(sdl.GetTicks(), game.ticks_count + 16) {
        // CPU使用率を下げるための待機
    }
    
    // デルタタイム（前フレームからの経過時間）の計算
    delta_time := f32(sdl.GetTicks() - game.ticks_count) / 1000.0
    
    // デルタタイムの上限設定（処理落ち対策）
    // 長時間の処理で大きなタイムステップになることを防ぐ
    if delta_time > 0.05 {
        delta_time = 0.05
    }
    
    game.ticks_count = sdl.GetTicks()
    
    // 全アクターの更新
    game.updating_actors = true
    for actor in game.actors {
        actor_update(actor, delta_time)
    }
    game.updating_actors = false
    
    // 追加待ちアクターをメインリストに移動
    // ゲームループ中のアクター追加を安全に処理
    for pending_actor in game.pending_actors {
        append(&game.actors, pending_actor)
    }
    clear(&game.pending_actors)
    
    // 削除対象アクターの処理
    dead_actors := make([dynamic]^Actor, context.temp_allocator)
    for actor in game.actors {
        if actor.state == .Dead {
            append(&dead_actors, actor)
        }
    }
    
    // 削除対象アクターをリストから削除して解放
    for dead_actor in dead_actors {
        for actor, i in game.actors {
            if actor == dead_actor {
                ordered_remove(&game.actors, i)
                break
            }
        }
        actor_destroy(dead_actor)
    }
    
    // 衝突判定の実行
    game_check_collisions(game)
}

// 画面描画処理
// 背景クリア→スプライト描画→画面更新
game_generate_output :: proc(game: ^Game) {
    // 背景色を設定（ライトグレー：宇宙空間を表現）
    sdl.SetRenderDrawColor(game.renderer, 220, 220, 220, 255)
    sdl.RenderClear(game.renderer)
    
    // スプライトを描画順序でソートして描画
    // TODO: 効率化のため、描画順序が変わった時のみソート
    for sprite in game.sprites {
        sprite_component_draw(sprite, game.renderer)
    }
    
    // フロントバッファとバックバッファを交換
    // 描画内容を画面に表示
    sdl.RenderPresent(game.renderer)
}

// ゲームデータの読み込み
// アクター作成、テクスチャ読み込み、初期配置の設定
game_load_data :: proc(game: ^Game) {
    // プレイヤーの宇宙船を作成
    game.ship = ship_create(game)
    actor_set_position(game.ship, Vec2{512, 384})  // 画面中央に配置
    actor_set_rotation(game.ship, -PI_OVER_2)      // 上向きに設定
    
    // 小惑星を作成（20個）
    // ランダムな位置に配置してゲーム開始
    asteroid_count :: 20
    for i in 0..<asteroid_count {
        asteroid := asteroid_create(game)
        
        // ランダムな位置に配置（画面端は避ける）
        pos := random_vector(50, 974, 50, 718)  // 画面サイズ1024x768からマージンを考慮
        actor_set_position(asteroid, pos)
        
        // ランダムな回転
        rotation := random_float(0, TWO_PI)
        actor_set_rotation(asteroid, rotation)
    }
}

// ゲームデータのアンロード
// 全リソースの解放とクリーンアップ
game_unload_data :: proc(game: ^Game) {
    // 全アクターを削除
    for actor in game.actors {
        actor_destroy(actor)
    }
    clear(&game.actors)
    
    // 追加待ちアクターも削除
    for actor in game.pending_actors {
        actor_destroy(actor)
    }
    clear(&game.pending_actors)
    
    // 全テクスチャを解放
    for filename, texture in game.textures {
        sdl.DestroyTexture(texture)
    }
    clear(&game.textures)
}

// ゲームの終了処理
// SDL、メモリなどのリソース解放
game_shutdown :: proc(game: ^Game) {
    game_unload_data(game)
    
    // SDL リソースの解放
    if game.renderer != nil {
        sdl.DestroyRenderer(game.renderer)
    }
    if game.window != nil {
        sdl.DestroyWindow(game.window)
    }
    
    // メモリの解放
    delete(game.actors)
    delete(game.pending_actors)
    delete(game.sprites)
    delete(game.textures)
    
    // SDL終了
    img.Quit()
    sdl.Quit()
}

// アクター管理関数
game_add_actor :: proc(game: ^Game, actor: ^Actor) {
    if game.updating_actors {
        // アクター更新中は追加待ちリストに追加
        append(&game.pending_actors, actor)
    } else {
        // 直接メインリストに追加
        append(&game.actors, actor)
    }
}

game_remove_actor :: proc(game: ^Game, actor: ^Actor) {
    // アクターを削除対象としてマーク
    actor.state = .Dead
}

// スプライト管理関数
game_add_sprite :: proc(game: ^Game, sprite: ^Sprite_Component) {
    // 描画順序に基づいて挿入位置を決定
    insert_index := len(game.sprites)
    for existing_sprite, i in game.sprites {
        if sprite.draw_order < existing_sprite.draw_order {
            insert_index = i
            break
        }
    }
    
    // 指定位置に挿入
    inject_at(&game.sprites, insert_index, sprite)
}

game_remove_sprite :: proc(game: ^Game, sprite: ^Sprite_Component) {
    for existing_sprite, i in game.sprites {
        if existing_sprite == sprite {
            ordered_remove(&game.sprites, i)
            break
        }
    }
}

// テクスチャ読み込み・管理
// ファイルからテクスチャを読み込み、キャッシュシステムで管理
game_get_texture :: proc(game: ^Game, filename: string) -> ^sdl.Texture {
    // 既に読み込み済みかチェック
    if texture, exists := game.textures[filename]; exists {
        return texture
    }
    
    // ファイルから画像を読み込み
    surface := img.Load(strings.clone_to_cstring(filename, context.temp_allocator))
    if surface == nil {
        sdl.Log("Failed to load texture: %s", filename)
        return nil
    }
    defer sdl.FreeSurface(surface)
    
    // テクスチャを作成
    texture := sdl.CreateTextureFromSurface(game.renderer, surface)
    if texture == nil {
        sdl.Log("Failed to create texture: %s", filename)
        return nil
    }
    
    // テクスチャをキャッシュに追加
    game.textures[strings.clone(filename)] = texture
    
    return texture
}

// 衝突判定システム
// レーザーと小惑星の衝突をチェック
game_check_collisions :: proc(game: ^Game) {
    // レーザーのリストを作成
    lasers := make([dynamic]^Actor, context.temp_allocator)
    asteroids := make([dynamic]^Actor, context.temp_allocator)
    
    for actor in game.actors {
        if actor.type == .Laser {
            append(&lasers, actor)
        } else if actor.type == .Asteroid {
            append(&asteroids, actor)
        }
    }
    
    // レーザーと小惑星の衝突判定
    for laser in lasers {
        if laser.state == .Dead do continue
        
        laser_circle := get_circle_component(laser)
        if laser_circle == nil do continue
        
        for asteroid in asteroids {
            if asteroid.state == .Dead do continue
            
            asteroid_circle := get_circle_component(asteroid)
            if asteroid_circle == nil do continue
            
            // 衝突判定
            if circle_intersect(laser_circle, asteroid_circle) {
                // 両方を削除
                laser.state = .Dead
                asteroid.state = .Dead
                break
            }
        }
    }
}

// アクターから特定タイプのコンポーネントを取得
get_circle_component :: proc(actor: ^Actor) -> ^Circle_Component {
    for component in actor.components {
        if component.type == .Circle {
            return cast(^Circle_Component)component
        }
    }
    return nil
}