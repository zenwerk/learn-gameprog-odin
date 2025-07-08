package chap03_asteroid

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
    
    return laser
}

// レーザー固有の更新処理
// 生存時間の管理と画面外での削除
laser_update_actor :: proc(laser: ^Actor, delta_time: f32) {
    // TODO: 生存時間タイマーを実装（1秒後に自動削除）
    // 現在は画面外に出たら削除する簡易実装
    
    screen_width: f32 = 1024
    screen_height: f32 = 768
    margin: f32 = 100
    
    pos := laser.position
    
    // 画面外に出たレーザーを削除
    if pos.x < -margin || pos.x > screen_width + margin ||
       pos.y < -margin || pos.y > screen_height + margin {
        laser.state = .Dead
    }
}