package chap02_ship

import sdl "vendor:sdl2"
import "core:strings"

// プレイヤーの宇宙船を表現する構造体
Ship :: struct {
    using base: Actor,  // Actorを継承
    
    // 移動速度
    right_speed: f32,  // 右方向への移動速度
    down_speed:  f32,  // 下方向への移動速度
    
    // コンポーネント参照（効率的なアクセスのため）
    sprite_component: ^Sprite_Component,
}

// 宇宙船の作成
ship_create :: proc(game: ^Game) -> ^Actor {
    // ベースアクターを作成
    ship_actor := actor_create(game)
    
    // Ship固有データの追加（union/variant型を使うかカスタムデータフィールドとして実装）
    // ここでは簡略化して、actor_update_actorで処理
    
    // スプライトコンポーネントを追加
    sprite := sprite_component_create(ship_actor, 150)  // 高い描画順序（前景）
    
    // 宇宙船のテクスチャを設定（プロジェクトルートから実行される前提）
    texture := game_get_texture(ship_actor.game, "src/chap02-ship/Assets/Ship01.png")
    if texture != nil {
        sdl.Log("Successfully loaded ship texture: Ship01.png")
    }
    
    if texture != nil {
        sprite_component_set_texture(sprite, texture)
    } else {
        // アセットがない場合のフォールバック
        // プログラムで白い矩形テクスチャを作成
        texture = game_create_solid_texture(ship_actor.game, 32, 32, 255, 255, 255, 255)
        if texture != nil {
            sprite_component_set_texture(sprite, texture)
        }
    }
    
    return ship_actor
}

// 宇宙船固有の更新処理
ship_update_actor :: proc(ship_actor: ^Actor, delta_time: f32) {
    // 移動速度の情報を取得（実際の実装では構造体のメンバーアクセス）
    // この例では、アクターに付加データを保存する方法を簡略化
    
    // 現在位置を取得
    pos := actor_get_position(ship_actor)
    
    // 右方向と下方向の速度を適用（キーボード入力に基づく）
    // 実際の速度値はship_process_keyboardで設定される
    
    // 画面境界での移動制限
    // 画面サイズは1024x768と仮定
    if pos.x < 25.0 {
        pos.x = 25.0
    } else if pos.x > 1000.0 {
        pos.x = 1000.0
    }
    
    if pos.y < 25.0 {
        pos.y = 25.0
    } else if pos.y > 743.0 {
        pos.y = 743.0
    }
    
    // 更新された位置を設定
    actor_set_position(ship_actor, pos)
}

// 宇宙船のキーボード入力処理
ship_process_keyboard :: proc(ship_actor: ^Actor, state: [^]u8) {
    // 移動速度をリセット
    right_speed: f32 = 0
    down_speed: f32 = 0
    
    // 方向キーによる移動
    if state[sdl.SCANCODE_D] != 0 || state[sdl.SCANCODE_RIGHT] != 0 {
        right_speed += 300.0  // 右に移動
    }
    if state[sdl.SCANCODE_A] != 0 || state[sdl.SCANCODE_LEFT] != 0 {
        right_speed -= 300.0  // 左に移動
    }
    if state[sdl.SCANCODE_S] != 0 || state[sdl.SCANCODE_DOWN] != 0 {
        down_speed += 300.0   // 下に移動
    }
    if state[sdl.SCANCODE_W] != 0 || state[sdl.SCANCODE_UP] != 0 {
        down_speed -= 300.0   // 上に移動
    }
    
    // 現在位置を取得
    pos := actor_get_position(ship_actor)
    
    // デルタタイムを概算（実際のゲームでは正確な値を使用）
    delta_time: f32 = 1.0 / 60.0  // 60FPSと仮定
    
    // 位置を更新
    pos.x += right_speed * delta_time
    pos.y += down_speed * delta_time
    
    // 更新された位置を設定
    actor_set_position(ship_actor, pos)
}

// 宇宙船の移動速度取得関数
ship_get_right_speed :: proc(ship_actor: ^Actor) -> f32 {
    // 実際の実装では構造体メンバーから取得
    // この例では簡略化
    return 0.0
}

ship_get_down_speed :: proc(ship_actor: ^Actor) -> f32 {
    // 実際の実装では構造体メンバーから取得
    // この例では簡略化
    return 0.0
}