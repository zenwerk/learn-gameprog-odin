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
    
    // 背景スプライトの更新（背景スクロールなど）
    for sprite in game.sprites {
        if sprite.type == .Background {
            sprite_component_update_background(sprite, delta_time)
        }
    }
    
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
    // 背景色を設定（黒色）
    sdl.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)
    sdl.RenderClear(game.renderer)
    
    // スプライトを描画順序でソートして描画
    // TODO: 効率化のため、描画順序が変わった時のみソート
    @(static) first_frame := true
    if first_frame && len(game.sprites) > 0 {
        sdl.Log("Total sprites: %d", len(game.sprites))
        first_frame = false
    }
    
    for sprite in game.sprites {
        // 背景スプライトの場合は専用描画関数を使用
        if sprite.type == .Background {
            sprite_component_draw_background(sprite, game.renderer)
        } else {
            sprite_component_draw(sprite, game.renderer)
        }
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
    actor_set_scale(game.ship, 1.5) // C++と同じスケール
    
    // 背景スクロールアクターを作成
    bg_actor := actor_create(game)
    actor_set_position(bg_actor, Vec2{512, 384})
    
    // 背景スプライトコンポーネントを作成
    bg_sprite := sprite_component_create(bg_actor, 10, .Background)
    sprite_component_set_screen_size(bg_sprite, Vec2{1024, 768})
    sprite_component_set_scroll_speed(bg_sprite, -100.0) // C++と同じ速度
    
    // 背景テクスチャを読み込み
    bg_textures := [2]^sdl.Texture{
        game_get_texture(game, "src/chap02-ship/Assets/Farback01.png"),
        game_get_texture(game, "src/chap02-ship/Assets/Farback02.png"),
    }
    
    // 有効なテクスチャのみを設定
    valid_textures := make([dynamic]^sdl.Texture, context.temp_allocator)
    for texture in bg_textures {
        if texture != nil {
            append(&valid_textures, texture)
        }
    }
    
    if len(valid_textures) > 0 {
        sprite_component_set_bg_textures(bg_sprite, valid_textures[:])
        sdl.Log("Successfully loaded %d background textures", len(valid_textures))
    } else {
        sdl.Log("WARNING: No background textures loaded!")
    }
    
    // 星の背景を作成（より手前のレイヤー）
    stars_actor := actor_create(game)
    actor_set_position(stars_actor, Vec2{512, 384})
    
    stars_sprite := sprite_component_create(stars_actor, 50, .Background)
    sprite_component_set_screen_size(stars_sprite, Vec2{1024, 768})
    sprite_component_set_scroll_speed(stars_sprite, -200.0) // 星は背景より速く
    
    // 星のテクスチャを読み込み
    stars_texture := game_get_texture(game, "src/chap02-ship/Assets/Stars.png")
    if stars_texture != nil {
        star_textures := [1]^sdl.Texture{stars_texture}
        sprite_component_set_bg_textures(stars_sprite, star_textures[:])
        sdl.Log("Successfully loaded stars texture")
    } else {
        sdl.Log("WARNING: Stars texture not loaded!")
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