package chap02_ship

import sdl "vendor:sdl2"
import img "vendor:sdl2/image"
import "core:strings"
import "core:mem"

// ゲームの状態を管理するメイン構造体
Game :: struct {
    // SDL関連
    window:   ^sdl.Window,    // ゲームウィンドウ
    renderer: ^sdl.Renderer,  // 描画用レンダラー
    
    // ゲームループ関連
    ticks_count:    u32,   // ゲーム開始からの経過時間
    is_running:     bool,  // ゲームが実行中かどうか
    updating_actors: bool, // アクター更新中フラグ（更新中の削除を防ぐ）
    
    // ゲームオブジェクト管理
    actors:         [dynamic]^Actor,           // 全アクター
    pending_actors: [dynamic]^Actor,           // 追加待ちアクター
    sprites:        [dynamic]^Sprite_Component, // 描画対象スプライト群
    
    // テクスチャ管理（ファイル名をキーとしたマップ）
    textures: map[string]^sdl.Texture,
    
    // ゲーム固有オブジェクト
    ship: ^Actor,  // プレイヤーの宇宙船
}

// ゲームの初期化
game_initialize :: proc(game: ^Game) -> bool {
    // macOSでのMachポートエラーを避けるため、VIDEOのみで初期化
    if sdl.Init({.VIDEO}) != 0 {
        sdl.Log("Unable to initialize SDL: %s", sdl.GetError())
        return false
    }
    
    // ウィンドウの作成
    game.window = sdl.CreateWindow(
        "Game Programming in Odin (Chapter 2)",
        100, 100,  // ウィンドウ位置
        1024, 768, // ウィンドウサイズ
        {},        // ウィンドウフラグ
    )
    
    if game.window == nil {
        sdl.Log("Failed to create window: %s", sdl.GetError())
        return false
    }
    
    // レンダラーの作成（ハードウェアアクセラレーション + VSync）
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
    
    // ゲームデータの読み込み
    game_load_data(game)
    
    // タイマーの初期化
    game.ticks_count = sdl.GetTicks()
    
    return true
}

// ゲームループの実行
game_run_loop :: proc(game: ^Game) {
    for game.is_running {
        game_process_input(game)
        game_update_game(game)
        game_generate_output(game)
    }
}

// 入力処理
game_process_input :: proc(game: ^Game) {
    event: sdl.Event
    
    // イベントキューを処理
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:
            game.is_running = false
        }
    }
    
    // キーボード状態を取得
    state := sdl.GetKeyboardState(nil)
    
    // ESCキーでゲーム終了
    if state[sdl.SCANCODE_ESCAPE] != 0 {
        game.is_running = false
    }
    
    // プレイヤー宇宙船の入力処理
    if game.ship != nil {
        ship_process_keyboard(game.ship, state)
    }
}

// ゲーム状態の更新
game_update_game :: proc(game: ^Game) {
    // フレームレート制御（60FPS = 16.67ms per frame）
    for !sdl.TICKS_PASSED(sdl.GetTicks(), game.ticks_count + 16) {
        // 待機
    }
    
    // デルタタイムの計算
    delta_time := f32(sdl.GetTicks() - game.ticks_count) / 1000.0
    
    // デルタタイムの上限設定（処理落ち対策）
    if delta_time > 0.05 {
        delta_time = 0.05
    }
    
    game.ticks_count = sdl.GetTicks()
    
    // アクターの更新
    game.updating_actors = true
    for actor in game.actors {
        actor_update(actor, delta_time)
    }
    game.updating_actors = false
    
    // 追加待ちアクターをメインリストに移動
    for pending_actor in game.pending_actors {
        append(&game.actors, pending_actor)
    }
    clear(&game.pending_actors)
    
    // Dead状態のアクターを削除
    dead_actors := make([dynamic]^Actor, context.temp_allocator)
    for actor, i in game.actors {
        if actor.state == .Dead {
            append(&dead_actors, actor)
        }
    }
    
    // Dead状態のアクターをリストから削除して解放
    for dead_actor in dead_actors {
        for actor, i in game.actors {
            if actor == dead_actor {
                ordered_remove(&game.actors, i)
                break
            }
        }
        actor_destroy(dead_actor)
    }
}

// 画面描画処理
game_generate_output :: proc(game: ^Game) {
    // 背景色を設定（濃い青色）
    sdl.SetRenderDrawColor(game.renderer, 0, 0, 100, 255)
    sdl.RenderClear(game.renderer)
    
    // スプライトを描画順序でソートして描画
    // TODO: 効率化のため、描画順序が変わった時のみソート
    @(static) first_frame := true
    if first_frame && len(game.sprites) > 0 {
        sdl.Log("Total sprites: %d", len(game.sprites))
        first_frame = false
    }
    
    for sprite in game.sprites {
        sprite_component_draw(sprite, game.renderer)
    }
    
    // フロントバッファとバックバッファを交換
    sdl.RenderPresent(game.renderer)
}

// ゲームデータの読み込み
game_load_data :: proc(game: ^Game) {
    // プレイヤーの宇宙船を作成
    game.ship = ship_create(game)
    actor_set_position(game.ship, Vec2{100, 384})  // 画面左側中央に配置
    actor_set_rotation(game.ship, 0.0) // デフォルトで右向き（回転なし）
    
    // 背景の作成（シンプルに普通のスプライトとして）
    temp_actor := actor_create(game)
    actor_set_position(temp_actor, Vec2{512, 384})  // 画面中央
    
    // 通常のスプライトコンポーネントを使用
    bg_sprite := sprite_component_create(temp_actor, 10)  // 低い描画順序（背景）
    
    // 背景画像を読み込み（プロジェクトルートから実行される前提）
    bg_texture := game_get_texture(game, "src/chap02-ship/Assets/Stars.png")
    if bg_texture != nil {
        sprite_component_set_texture(bg_sprite, bg_texture)
        sdl.Log("Successfully loaded background texture: Stars.png")
        // 背景を画面サイズに合わせて拡大
        actor_set_scale(temp_actor, 2.0)
    } else {
        // フォールバックとして他の背景を試す
        bg_texture = game_get_texture(game, "src/chap02-ship/Assets/Farback01.png")
        if bg_texture != nil {
            sprite_component_set_texture(bg_sprite, bg_texture)
            sdl.Log("Successfully loaded background texture: Farback01.png")
            actor_set_scale(temp_actor, 1.5)
        } else {
            sdl.Log("WARNING: No background textures loaded!")
        }
    }
}

// ゲームデータのアンロード
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
game_get_texture :: proc(game: ^Game, filename: string) -> ^sdl.Texture {
    // 既に読み込み済みかチェック
    if texture, exists := game.textures[filename]; exists {
        return texture
    }
    
    // ファイルから画像を読み込み
    surface := img.Load(strings.clone_to_cstring(filename, context.temp_allocator))
    if surface == nil {
        // ログは不要（呼び出し側で処理）
        return nil
    }
    defer sdl.FreeSurface(surface)
    
    // テクスチャを作成
    texture := sdl.CreateTextureFromSurface(game.renderer, surface)
    if texture == nil {
        // ログは不要（呼び出し側で処理）
        return nil
    }
    
    // テクスチャをキャッシュに追加
    game.textures[strings.clone(filename)] = texture
    
    return texture
}

// 単色のテクスチャを作成（フォールバック用）
game_create_solid_texture :: proc(game: ^Game, width, height: int, r, g, b, a: u8) -> ^sdl.Texture {
    // フォーマットを指定してテクスチャを作成
    texture := sdl.CreateTexture(game.renderer, sdl.PixelFormatEnum.RGBA8888, .TARGET, i32(width), i32(height))
    if texture == nil {
        return nil
    }
    
    // テクスチャを描画ターゲットに設定
    old_target := sdl.GetRenderTarget(game.renderer)
    sdl.SetRenderTarget(game.renderer, texture)
    
    // 指定された色で塗りつぶし
    sdl.SetRenderDrawColor(game.renderer, r, g, b, a)
    sdl.RenderClear(game.renderer)
    
    // 元の描画ターゲットに戻す
    sdl.SetRenderTarget(game.renderer, old_target)
    
    return texture
}