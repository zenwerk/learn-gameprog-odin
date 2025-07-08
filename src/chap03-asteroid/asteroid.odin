package chap03_asteroid

// 小惑星アクターを作成
// 一定速度で移動し、レーザーとの衝突判定を持つ
asteroid_create :: proc(game: ^Game) -> ^Actor {
    // 小惑星アクターを作成
    asteroid := actor_create(game, .Asteroid)
    
    // 移動コンポーネントを追加
    // 小惑星は一定速度で直進する
    move := move_component_create(asteroid)
    move.forward_speed = 150.0  // 中程度の速度で移動
    
    // スプライト描画コンポーネントを追加
    sprite := sprite_component_create(asteroid, 100)  // 標準の描画順序
    
    // 小惑星のテクスチャを読み込み・設定
    texture := game_get_texture(game, "src/chap03-asteroid/Assets/Asteroid.png")
    if texture != nil {
        sprite_component_set_texture(sprite, texture)
    }
    
    // 円形衝突判定コンポーネントを追加
    // レーザーとの衝突を検出するため
    circle := circle_component_create(asteroid, 40.0)  // 半径40ピクセル
    
    return asteroid
}

// 小惑星固有の更新処理
// 画面外に出た場合の処理などを実装
asteroid_update_actor :: proc(asteroid: ^Actor, delta_time: f32) {
    // 画面外に出た小惑星を反対側から再登場させる
    // （ラップアラウンド処理）
    screen_width: f32 = 1024
    screen_height: f32 = 768
    margin: f32 = 50  // 画面端からのマージン
    
    pos := asteroid.position
    
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
    
    asteroid.position = pos
}