package chap03_asteroid

// レーザー固有のデータ
// 生存時間タイマーを管理
Laser_Data :: struct {
    death_timer: f32,  // 生存時間タイマー（秒）
}

// グローバルマップでアクターIDとレーザーデータを関連付け
laser_data_map: map[rawptr]Laser_Data

// レーザー弾アクターを作成
// 直進し、一定時間後に消滅、小惑星との衝突判定を持つ
laser_create :: proc(game: ^Game) -> ^Actor {
    // レーザーアクターを作成
    laser := actor_create(game, .Laser)
    
    // 移動コンポーネントを追加
    // レーザーは高速で直進する
    move := move_component_create(laser)
    move.forward_speed = 800.0  // 高速移動
    
    // スプライト描画コンポーネントを追加
    sprite := sprite_component_create(laser, 120)  // 船より前面に描画
    
    // レーザーのテクスチャを読み込み・設定
    texture := game_get_texture(game, "src/chap03-asteroid/Assets/Laser.png")
    if texture != nil {
        sprite_component_set_texture(sprite, texture)
    }
    
    // 円形衝突判定コンポーネントを追加
    // 小惑星との衝突を検出するため
    circle := circle_component_create(laser, 11.0)  // 小さな半径
    
    // レーザー固有データを初期化
    laser_data_map[laser] = Laser_Data{
        death_timer = 1.0,  // 1秒後に消滅
    }
    
    return laser
}

// レーザー固有の更新処理
// 生存時間の管理とラップアラウンド処理
laser_update_actor :: proc(laser: ^Actor, delta_time: f32) {
    // 生存時間タイマーを更新
    if laser_data, ok := &laser_data_map[laser]; ok {
        laser_data.death_timer -= delta_time
        
        // 時間切れで削除
        if laser_data.death_timer <= 0.0 {
            laser.state = .Dead
            return
        }
    }
    
    // 画面外に出たレーザーを反対側から再登場させる
    // （ラップアラウンド処理）
    screen_width: f32 = 1024
    screen_height: f32 = 768
    margin: f32 = 25  // レーザーのサイズを考慮した小さめのマージン
    
    pos := laser.position
    
    // X軸のラップアラウンド
    if pos.x < -margin {
        pos.x = screen_width + margin
    } else if pos.x > screen_width + margin {
        pos.x = -margin
    }
    
    // Y軸のラップアラウンド
    if pos.y < -margin {
        pos.y = screen_height + margin
    } else if pos.y > screen_height + margin {
        pos.y = -margin
    }
    
    laser.position = pos
}