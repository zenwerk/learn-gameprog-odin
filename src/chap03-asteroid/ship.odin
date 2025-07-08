package chap03_asteroid

import sdl "vendor:sdl2"

// 宇宙船固有のデータ
// レーザーのクールダウンタイマーなどを管理
Ship_Data :: struct {
    laser_cooldown: f32,  // レーザーのクールダウンタイマー（秒）
}

// グローバルマップでアクターIDと宇宙船データを関連付け
// 注意：実際のゲームでは、より洗練された方法（ECSなど）を推奨
ship_data_map: map[rawptr]Ship_Data

// プレイヤーの宇宙船を作成
// 入力処理、移動、描画、レーザー発射機能を持つ
ship_create :: proc(game: ^Game) -> ^Actor {
    // 宇宙船アクターを作成
    ship := actor_create(game, .Ship)
    
    // 入力処理コンポーネントを追加
    // プレイヤーのキーボード入力で移動を制御
    input := input_component_create(ship)
    input.max_forward_speed = 300.0   // 最大前進速度
    input.max_angular_speed = TWO_PI  // 最大回転速度（1秒で1回転）
    
    // スプライト描画コンポーネントを追加
    sprite := sprite_component_create(ship, 150)  // 高い描画順序（前景）
    
    // 宇宙船のテクスチャを読み込み・設定
    texture := game_get_texture(game, "src/chap03-asteroid/Assets/Ship.png")
    if texture != nil {
        sprite_component_set_texture(sprite, texture)
    }
    
    // 宇宙船固有データを初期化
    ship_data_map[ship] = Ship_Data{
        laser_cooldown = 0.0,
    }
    
    return ship
}

// 宇宙船の入力処理
// レーザー発射などの船固有の操作を処理
ship_process_input :: proc(ship: ^Actor, keyboard_state: [^]u8) {
    // スペースキーでレーザー発射（クールダウン中でなければ）
    if keyboard_state[sdl.SCANCODE_SPACE] != 0 {
        if ship_data, ok := &ship_data_map[ship]; ok {
            if ship_data.laser_cooldown <= 0.0 {
                ship_fire_laser(ship)
                ship_data.laser_cooldown = 0.5  // 0.5秒のクールダウン
            }
        }
    }
}

// 宇宙船固有の更新処理
// レーザーのクールダウンタイマーなどを管理
ship_update_actor :: proc(ship: ^Actor, delta_time: f32) {
    // レーザーのクールダウンタイマーを更新
    if ship_data, ok := &ship_data_map[ship]; ok {
        if ship_data.laser_cooldown > 0.0 {
            ship_data.laser_cooldown -= delta_time
        }
    }
}

// レーザー発射処理
// 宇宙船の位置と向きに基づいてレーザーを生成
ship_fire_laser :: proc(ship: ^Actor) {
    if ship == nil || ship.game == nil {
        return
    }
    
    // レーザーアクターを作成
    laser := laser_create(ship.game)
    
    // 宇宙船の位置と向きに基づいてレーザーの初期状態を設定
    laser_pos := ship.position
    laser_forward := actor_get_forward(ship)
    
    // レーザーを宇宙船の少し前方に配置
    laser_pos += laser_forward * 30.0
    actor_set_position(laser, laser_pos)
    actor_set_rotation(laser, ship.rotation)
    
    // レーザーの移動コンポーネントに速度を設定
    move := get_move_component(laser)
    if move != nil {
        move.forward_speed = 800.0  // 高速で前進
    }
}

// アクターから移動コンポーネントを取得
get_move_component :: proc(actor: ^Actor) -> ^Move_Component {
    for component in actor.components {
        if component.type == .Move {
            return cast(^Move_Component)component
        }
    }
    return nil
}